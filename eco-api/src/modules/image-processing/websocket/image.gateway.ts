import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({
  cors: { origin: '*' }, // adjust for security
})
export class ImageGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private clients = new Map<string, Socket>();

  handleConnection(client: Socket) {
    console.log(`Client connected: ${client.id}`);
    this.clients.set(client.id, client);
  }

  handleDisconnect(client: Socket) {
    console.log(`Client disconnected: ${client.id}`);
    this.clients.delete(client.id);
  }

  // Emit result from models
  sendPartialResult(clientId: string, modelName: string, result: unknown) {
    const client = this.clients.get(clientId);
    if (client) {
      client.emit('modelResult', { model: modelName, result });
    }
  }

  // Emit final comparison
  sendFinalResult(clientId: string, comparison: unknown) {
    const client = this.clients.get(clientId);
    if (client) {
      client.emit('finalResult', comparison);
      client.disconnect(true);
    }
  }
}
