import { Injectable, OnModuleInit } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { ClientGrpc } from '@nestjs/microservices';
import { lastValueFrom, Observable } from 'rxjs';
import { Models } from '../grpc.constants';

interface ModelService {
  ProcessImage(data: { imageBuffer: Buffer }): Observable<{
    accuracy: number;
    executionTime: number;
    hardware: string;
  }>;
}

@Injectable()
export class GrpcClientService implements OnModuleInit {
  private readonly services = new Map<string, ModelService>();

  constructor(private readonly moduleRef: ModuleRef) {}

  onModuleInit() {
    Models.forEach((model) => {
      const client = this.moduleRef.get<ClientGrpc>(model.name, {
        strict: false,
      });

      if (!client) {
        throw new Error(`GRPC client not found for model: ${model.name}`);
      }

      const service = client.getService<ModelService>('ModelService');
      this.services.set(model.name, service);
    });
  }

  async callModel(modelName: string, image: Buffer): Promise<any> {
    const service = this.services.get(modelName);
    if (!service) throw new Error(`Model service not found: ${modelName}`);

    const response$ = service.ProcessImage({ imageBuffer: image });
    return await lastValueFrom(response$);
  }
}
