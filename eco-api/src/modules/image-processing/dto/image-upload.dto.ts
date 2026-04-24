import { ApiProperty } from '@nestjs/swagger';

export class ProcessImageDTO {
  clientId: string;

  @ApiProperty({ type: [String] })
  models: string;

  @ApiProperty({ type: 'string', format: 'binary', required: true })
  image?: any;
}
