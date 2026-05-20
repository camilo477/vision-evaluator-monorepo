import { Injectable } from '@nestjs/common';
import { readFileSync } from 'fs';
import { cpus } from 'os';
import { ImageGateway } from '../websocket/image.gateway';
import { GrpcClientService } from 'src/modules/grpc-clients/services/grpc-clients.service';
import { Models } from 'src/modules/grpc-clients/grpc.constants';

type PerformanceMetrics = {
  preprocessMs: number;
  inferenceMs: number;
  postprocessMs: number;
  totalMs: number;
};

type DetectionResult = {
  className?: string;
  confidence?: number;
  xMin?: number;
  yMin?: number;
  xMax?: number;
  yMax?: number;
  xCenter?: number;
  yCenter?: number;
  x_min?: number;
  y_min?: number;
  x_max?: number;
  y_max?: number;
  x_center?: number;
  y_center?: number;
  width?: number;
  height?: number;
  normalized?: boolean;
};

type ResourceMetrics = {
  scope: string;
  elapsedMs: number;
  cpuMs: number;
  cpuPercent: number;
  memoryRssMb: number;
  heapUsedMb: number;
};

type GroundTruthEvaluation = {
  expectedLabels: string[];
  detectedLabels: string[];
  matchedLabels: string[];
  missedLabels: string[];
  falsePositiveLabels: string[];
  truePositives: number;
  falsePositives: number;
  falseNegatives: number;
  precision: number;
  recall: number;
  f1: number;
};

type ModelResponse = {
  modelInfo?: Record<string, unknown>;
  imageInfo?: Record<string, unknown>;
  metrics?: Partial<PerformanceMetrics>;
  detections?: DetectionResult[];
  detectionsCount?: number;
  fps?: number;
  evaluation?: GroundTruthEvaluation;
  resourceMetrics?: ResourceMetrics;
  [key: string]: unknown;
};

type ModelRun = {
  modelName: string;
  result?: ModelResponse;
  error?: string;
};

type ResourceSnapshot = {
  startedAt: bigint;
  cpuUsage: NodeJS.CpuUsage;
};

@Injectable()
export class ImageService {
  constructor(
    private readonly grpcClient: GrpcClientService,
    private readonly gateway: ImageGateway,
  ) {}

  async testModelA(): Promise<unknown> {
    const img = readFileSync('test.jpg');
    const result = (await this.grpcClient.callModel('YOLOv8n', img)) as unknown;
    return result;
  }

  getModels() {
    return Models.map((model) => ({
      name: model.name,
      type: model.recognizes,
    }));
  }

  async processImage(
    imageBuffer: Buffer,
    clientId: string,
    models: string[],
    groundTruthLabels: string[] = [],
  ): Promise<{ message: string }> {
    const normalizedGroundTruth = this.normalizeGroundTruth(groundTruthLabels);
    const promises = models.map(async (modelName) => {
      const resourceSnapshot = this.startResourceSnapshot();

      try {
        const rawResult = (await this.grpcClient.callModel(
          modelName,
          imageBuffer,
        )) as ModelResponse;
        const result = this.enrichResult(
          rawResult,
          this.finishResourceSnapshot(resourceSnapshot),
          normalizedGroundTruth,
        );

        this.gateway.sendPartialResult(clientId, modelName, result);
        return { modelName, result };
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error';
        this.gateway.sendPartialResult(clientId, modelName, {
          error: message,
          resourceMetrics: this.finishResourceSnapshot(resourceSnapshot),
        });

        return { modelName, error: message };
      }
    });

    const allResults = await Promise.all(promises);
    const comparison = this.compareResults(allResults, normalizedGroundTruth);

    this.gateway.sendFinalResult(clientId, comparison);
    return { message: 'Processing started. Results will be streamed.' };
  }

  private compareResults(results: ModelRun[], groundTruthLabels: string[]) {
    const useGroundTruth = groundTruthLabels.length > 0;
    const scored = results.map((run) => {
      const detections = run.result?.detections ?? [];
      const sortedDetections = [...detections].sort(
        (a, b) => (b.confidence ?? 0) - (a.confidence ?? 0),
      );
      const metrics = this.completeMetrics(run.result?.metrics);
      const bestConfidence = sortedDetections[0]?.confidence ?? 0;

      const groundTruthScore = run.result?.evaluation?.f1 ?? 0;

      return {
        modelName: run.modelName,
        score: useGroundTruth ? groundTruthScore : bestConfidence,
        confidenceScore: bestConfidence,
        detectionsCount: detections.length,
        fps: this.calculateFps(metrics.inferenceMs),
        metrics,
        evaluation: run.result?.evaluation,
        resourceMetrics: run.result?.resourceMetrics,
        error: run.error,
        raw: run.result,
      };
    });

    const valid = scored.filter((item) =>
      useGroundTruth ? !item.error : !item.error && item.detectionsCount > 0,
    );

    if (valid.length === 0) {
      return {
        bestModel: 'N/A',
        accuracy: 0,
        accuracyMethod: useGroundTruth ? 'ground_truth_f1' : 'confidence_proxy',
        groundTruthLabels,
        detectionsCount: 0,
        fps: 0,
        metrics: this.completeMetrics(),
        results: scored,
        errors: scored.filter((item) => item.error),
      };
    }

    valid.sort((a, b) => b.score - a.score);
    const best = valid[0];

    return {
      bestModel: best.modelName,
      accuracy: best.score,
      confidence: best.confidenceScore,
      accuracyMethod: useGroundTruth ? 'ground_truth_f1' : 'confidence_proxy',
      groundTruthLabels,
      detectionsCount: best.detectionsCount,
      fps: best.fps,
      metrics: best.metrics,
      evaluation: best.evaluation,
      resourceMetrics: best.resourceMetrics,
      results: scored,
      errors: scored.filter((item) => item.error),
    };
  }

  private enrichResult(
    result: ModelResponse,
    resourceMetrics: ResourceMetrics,
    groundTruthLabels: string[],
  ): ModelResponse {
    const metrics = this.completeMetrics(result.metrics);
    const detections = result.detections ?? [];

    return {
      ...result,
      metrics,
      detections,
      detectionsCount: detections.length,
      fps: this.calculateFps(metrics.inferenceMs),
      evaluation:
        groundTruthLabels.length > 0
          ? this.evaluateGroundTruth(detections, groundTruthLabels)
          : undefined,
      resourceMetrics,
    };
  }

  private evaluateGroundTruth(
    detections: DetectionResult[],
    expectedLabels: string[],
  ): GroundTruthEvaluation {
    const matchedIndexes = new Set<number>();
    const detectedLabels: string[] = [];
    const matchedLabels: string[] = [];
    const falsePositiveLabels: string[] = [];

    for (const detection of detections) {
      const candidates = this.detectionCandidates(detection);
      const displayLabel = detection.className ?? 'unknown';
      detectedLabels.push(displayLabel);

      const matchedIndex = expectedLabels.findIndex((expected, index) => {
        return (
          !matchedIndexes.has(index) &&
          candidates.some((candidate) => this.labelsMatch(candidate, expected))
        );
      });

      if (matchedIndex >= 0) {
        matchedIndexes.add(matchedIndex);
        matchedLabels.push(expectedLabels[matchedIndex]);
      } else {
        falsePositiveLabels.push(displayLabel);
      }
    }

    const missedLabels = expectedLabels.filter(
      (_label, index) => !matchedIndexes.has(index),
    );
    const truePositives = matchedIndexes.size;
    const falsePositives = falsePositiveLabels.length;
    const falseNegatives = missedLabels.length;
    const precision =
      truePositives + falsePositives > 0
        ? truePositives / (truePositives + falsePositives)
        : 0;
    const recall =
      truePositives + falseNegatives > 0
        ? truePositives / (truePositives + falseNegatives)
        : 0;
    const f1 =
      precision + recall > 0
        ? (2 * precision * recall) / (precision + recall)
        : 0;

    return {
      expectedLabels,
      detectedLabels,
      matchedLabels,
      missedLabels,
      falsePositiveLabels,
      truePositives,
      falsePositives,
      falseNegatives,
      precision,
      recall,
      f1,
    };
  }

  private detectionCandidates(detection: DetectionResult): string[] {
    const label = detection.className ?? '';
    const pieces = label.split(':').map((part) => part.trim());

    return [label, ...pieces]
      .map((candidate) => this.normalizeLabel(candidate))
      .filter(Boolean);
  }

  private labelsMatch(detected: string, expected: string): boolean {
    return (
      detected === expected ||
      detected.includes(expected) ||
      expected.includes(detected)
    );
  }

  private normalizeGroundTruth(labels: string[]) {
    return labels.map((label) => this.normalizeLabel(label)).filter(Boolean);
  }

  private normalizeLabel(label: string) {
    const normalized = label
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .toLowerCase()
      .replace(/[_-]/g, ' ')
      .replace(/[^a-z0-9 ]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    const aliases: Record<string, string> = {
      auto: 'car',
      automovil: 'car',
      carro: 'car',
      coche: 'car',
      persona: 'person',
      personas: 'person',
      botella: 'bottle',
      botellas: 'bottle',
      silla: 'chair',
      sillas: 'chair',
      mesa: 'dining table',
      mesas: 'dining table',
      celular: 'cell phone',
      telefono: 'cell phone',
      perro: 'dog',
      gato: 'cat',
      bicicleta: 'bicycle',
      moto: 'motorcycle',
      motocicleta: 'motorcycle',
    };

    return aliases[normalized] ?? normalized;
  }

  private completeMetrics(metrics?: Partial<PerformanceMetrics>) {
    return {
      preprocessMs: Number(metrics?.preprocessMs ?? 0),
      inferenceMs: Number(metrics?.inferenceMs ?? 0),
      postprocessMs: Number(metrics?.postprocessMs ?? 0),
      totalMs: Number(metrics?.totalMs ?? 0),
    };
  }

  private calculateFps(inferenceMs: number) {
    return inferenceMs > 0 ? 1000 / inferenceMs : 0;
  }

  private startResourceSnapshot(): ResourceSnapshot {
    return {
      startedAt: process.hrtime.bigint(),
      cpuUsage: process.cpuUsage(),
    };
  }

  private finishResourceSnapshot(snapshot: ResourceSnapshot): ResourceMetrics {
    const elapsedMs =
      Number(process.hrtime.bigint() - snapshot.startedAt) / 1_000_000;
    const cpuUsage = process.cpuUsage(snapshot.cpuUsage);
    const cpuMs = (cpuUsage.user + cpuUsage.system) / 1000;
    const cpuPercent =
      elapsedMs > 0
        ? (cpuMs / (elapsedMs * Math.max(cpus().length, 1))) * 100
        : 0;
    const memory = process.memoryUsage();

    return {
      scope: 'backend_process',
      elapsedMs,
      cpuMs,
      cpuPercent,
      memoryRssMb: memory.rss / 1024 / 1024,
      heapUsedMb: memory.heapUsed / 1024 / 1024,
    };
  }
}
