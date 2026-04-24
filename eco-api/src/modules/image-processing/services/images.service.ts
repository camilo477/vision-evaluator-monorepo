import { Injectable } from '@nestjs/common';
import { ImageGateway } from '../websocket/image.gateway';
import { GrpcClientService } from 'src/modules/grpc-clients/services/grpc-clients.service';
import { randomUUID } from 'crypto';
import { Models } from 'src/modules/grpc-clients/grpc.constants';

@Injectable()
export class ImageService {
  constructor(
    private readonly grpcClient: GrpcClientService,
    private readonly gateway: ImageGateway,
  ) {}

  async testModelA() {
    const fs = require('fs');
    const img = fs.readFileSync('test.jpg');
    const result = await this.grpcClient.callModel('MODEL_A', img);
    return result;
  }

  async getModels() {
    const models = Models.map((model) => {
      return {
        name: model.name,
        type: model.recognizes,
      };
    });
    return models;
  }

  async processImage(
    imageBuffer: Buffer,
    clientId: string,
    models: string[],
  ): Promise<{ message: string }> {
    const promises = models.map(async (modelName) => {
      try {
        const id = randomUUID();
        const result = await this.grpcClient.callModel(modelName, imageBuffer);
        this.gateway.sendPartialResult(clientId, modelName, result);
        return { modelName, result };
      } catch (err) {
        this.gateway.sendPartialResult(clientId, modelName, {
          error: err.message,
        });
        return { modelName, error: err.message };
      }
    });

    const allResults = await Promise.all(promises);
    const comparison = this.compareResults(allResults);

    this.gateway.sendFinalResult(clientId, comparison);
    return { message: 'Processing started. Results will be streamed.' };
  }

  private compareResults(results: any[]) {
  const scored = results.map(r => {
    const detections = r.result?.detections ?? [];

    // ordenar detecciones por confidence
    detections.sort((a, b) => b.confidence - a.confidence);

    const bestConfidence =
      detections.length > 0 ? detections[0].confidence : 0;

    const metrics = r.result?.metrics ?? {
      preprocessMs: 0,
      inferenceMs: 0,
      postprocessMs: 0,
      totalMs: 0,
    };

    return {
      modelName: r.modelName,
      score: bestConfidence,
      detectionsCount: detections.length,
      metrics,
      raw: r.result
    };
  });

  const valid = scored.filter(s => s.score !== undefined && s.score !== null);

  if (valid.length === 0) {
    return {
      bestModel: "N/A",
      accuracy: 0,
      detectionsCount: 0,
      metrics: { preprocessMs: 0, inferenceMs: 0, postprocessMs: 0, totalMs: 0 }
    };
  }

  valid.sort((a, b) => b.score - a.score);

  const best = valid[0];

  return {
    bestModel: best.modelName,
    accuracy: best.score,
    detectionsCount: best.detectionsCount,
    metrics: best.metrics
  };
}



}
