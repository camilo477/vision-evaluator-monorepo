import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ImageProcessingModule } from './modules/image-processing/image-processing.module';
import { GrpcClientModule } from './modules/grpc-clients/grpc-clients.module';

@Module({
  imports: [ImageProcessingModule, GrpcClientModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
