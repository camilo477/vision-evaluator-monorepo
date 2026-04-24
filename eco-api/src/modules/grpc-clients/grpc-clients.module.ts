import { Module } from '@nestjs/common';
import { ClientsModule } from '@nestjs/microservices';
import { GrpcClientService } from './services/grpc-clients.service';
import { ModelsServers } from './grpc.constants';

@Module({
  imports: [ClientsModule.register(ModelsServers)],
  providers: [GrpcClientService],
  exports: [GrpcClientService],
})
export class GrpcClientModule {}
