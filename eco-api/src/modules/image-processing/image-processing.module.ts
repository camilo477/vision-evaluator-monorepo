import { Module } from '@nestjs/common';
import { ImageService } from './services/images.service';
import { ImageGateway } from './websocket/image.gateway';
import { ImageController } from './controllers/image-processing.controller';
import { GrpcClientModule } from '../grpc-clients/grpc-clients.module';

@Module({
  imports: [GrpcClientModule],
  controllers: [ImageController],
  providers: [ImageService, ImageGateway],
})
export class ImageProcessingModule {}
