import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class ProcessImageDTO {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  clientId: string;

  @ApiProperty({ type: String })
  @IsString()
  @IsNotEmpty()
  models: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  groundTruth?: string;

  @ApiProperty({ type: 'string', format: 'binary', required: true })
  image?: any;
}
