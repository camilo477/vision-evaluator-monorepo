import {
  Controller,
  Post,
  Body,
  UploadedFile,
  UseInterceptors,
  Req,
  Get,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ImageService } from '../services/images.service';
import { ProcessImageDTO } from '../dto/image-upload.dto';
import { ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';

@ApiTags('Image Processing')
@Controller('image')
export class ImageController {
  constructor(private readonly imageService: ImageService) {}

  @Get('test')
  async test() {
    return this.imageService.testModelA();
  }

  @Get('models')
  async getModels() {
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
    @Req() req: Request,
  ) {
    const { clientId, models }: ProcessImageDTO = req.body;
    const modelsArray = models.split(',').map((s) => s.trim());
    return this.imageService.processImage(file.buffer, clientId, modelsArray);
  }
}
