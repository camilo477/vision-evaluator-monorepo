import {
  ClientProviderOptions,
  ClientsModuleOptions,
  Transport,
} from '@nestjs/microservices';
import { join } from 'path';

export enum RecognitionTypes {
  OBJECTS = 'OBJECTS',
  CODES = 'CODES',
  TEXT = 'TEXT',
}

export type ModelPropertires = {
  name: string;
  transport: Transport;
  recognizes: RecognitionTypes;
  options: {
    package: string;
    protoPath: string | string[];
    url: string;
  };
};

const sharedOptions = {
  package: 'model',
  protoPath: join(__dirname, 'proto/model.proto'),
};

const modelUrl = (envName: string, fallback: string) =>
  process.env[envName] ?? fallback;

export const Models: ModelPropertires[] = [
  {
    name: 'YOLOv8n',
    transport: Transport.GRPC,
    recognizes: RecognitionTypes.OBJECTS,
    options: {
      ...sharedOptions,
      url: modelUrl('YOLOV8N_GRPC_URL', 'localhost:50051'),
    },
  },
  {
    name: 'YOLOv5n',
    recognizes: RecognitionTypes.OBJECTS,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('YOLOV5N_GRPC_URL', 'localhost:50052'),
    },
  },
  {
    name: 'EfficientDet',
    recognizes: RecognitionTypes.OBJECTS,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('EFFICIENTDET_GRPC_URL', 'localhost:50053'),
    },
  },
  {
    name: 'MobileNet',
    recognizes: RecognitionTypes.OBJECTS,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('MOBILENET_GRPC_URL', 'localhost:50054'),
    },
  },
  {
    name: 'ResNet50',
    recognizes: RecognitionTypes.OBJECTS,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('RESNET50_GRPC_URL', 'localhost:50062'),
    },
  },
  {
    name: 'PaddleOCR',
    recognizes: RecognitionTypes.TEXT,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('PADDLEOCR_GRPC_URL', 'localhost:50055'),
    },
  },
  {
    name: 'EasyOCR',
    recognizes: RecognitionTypes.TEXT,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('EASYOCR_GRPC_URL', 'localhost:50056'),
    },
  },
  {
    name: 'TesseractOCR',
    recognizes: RecognitionTypes.TEXT,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('TESSERACTOCR_GRPC_URL', 'localhost:50057'),
    },
  },
  {
    name: 'CRAFTCRNN',
    recognizes: RecognitionTypes.TEXT,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('CRAFTCRNN_GRPC_URL', 'localhost:50058'),
    },
  },
  {
    name: 'ZBar',
    recognizes: RecognitionTypes.CODES,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('ZBAR_GRPC_URL', 'localhost:50059'),
    },
  },
  {
    name: 'ZXing',
    recognizes: RecognitionTypes.CODES,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('ZXING_GRPC_URL', 'localhost:50060'),
    },
  },
  {
    name: 'pybarcode',
    recognizes: RecognitionTypes.CODES,
    transport: Transport.GRPC,
    options: {
      ...sharedOptions,
      url: modelUrl('PYBARCODE_GRPC_URL', 'localhost:50061'),
    },
  },
];

export const ModelsServers: ClientsModuleOptions = Models.map((model) => {
  return {
    name: model.name,
    transport: model.transport,
    options: {
      package: model.options.package,
      protoPath: model.options.protoPath,
      url: model.options.url,
    },
  } as ClientProviderOptions;
});
