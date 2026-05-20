import {
  BadRequestException,
  Controller,
  Post,
  Body,
  UploadedFile,
  UseInterceptors,
  Get,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ImageService } from '../services/images.service';
import { ProcessImageDTO } from '../dto/image-upload.dto';
import { ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';

@ApiTags('Image Processing')
@Controller('image')
export class ImageController {
  constructor(private readonly imageService: ImageService) {}

  @Get('test')
  async test(): Promise<unknown> {
    return this.imageService.testModelA();
  }

  @Get('models')
  getModels() {
    return this.imageService.getModels();
  }

  @Post('process')
  @UseInterceptors(FileInterceptor('image'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    description: 'Process Images',
    type: ProcessImageDTO,
  })
  async processImage(
    @UploadedFile() file: Express.Multer.File,
    @Body() body: ProcessImageDTO,
  ) {
    if (!file?.buffer) {
      throw new BadRequestException('Image file is required.');
    }

    if (!body.clientId) {
      throw new BadRequestException('clientId is required.');
    }

    if (!body.models) {
      throw new BadRequestException('At least one model is required.');
    }

    const modelsArray = body.models
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);

    if (modelsArray.length === 0) {
      throw new BadRequestException('At least one model is required.');
    }

    return this.imageService.processImage(
      file.buffer,
      body.clientId,
      modelsArray,
      this.parseCsvList(body.groundTruth),
    );
  }

  private parseCsvList(value?: string): string[] {
    if (!value) {
      return [];
    }

    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }
}
