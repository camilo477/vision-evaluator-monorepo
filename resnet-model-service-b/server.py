import grpc
from concurrent import futures
import time
import model_pb2
import model_pb2_grpc

import torch
import torchvision.transforms as transforms
from torchvision import models

from PIL import Image
import io


# ================================
#   Cargar etiquetas ImageNet
# ================================
with open("imagenet_classes.txt", "r") as f:
    IMAGENET_CLASSES = [line.strip() for line in f.readlines()]


# ================================
#   SERVICIO gRPC
# ================================
class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Cargando ResNet50 (ImageNet)...")

        # modelo oficial torchvision
        self.model = models.resnet50(weights=models.ResNet50_Weights.DEFAULT)
        self.model.eval()

        self.device = "cpu"
        print("[MODEL] Modelo cargado en CPU")

        # Transformaciones estándar ImageNet
        self.transform = transforms.Compose([
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            ),
        ])

    # ================================
    #   Procesamiento gRPC
    # ================================
    def ProcessImage(self, request, context):

        total_start = time.time()

        # --------------------------------
        # Preprocesamiento
        # --------------------------------
        pre_start = time.time()

        try:
            image = Image.open(io.BytesIO(request.imageBuffer)).convert("RGB")
        except:
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details("Error leyendo la imagen")
            return model_pb2.ModelResponse()

        w, h = image.size

        img_tensor = self.transform(image).unsqueeze(0)
        pre_end = time.time()

        # --------------------------------
        # Inferencia
        # --------------------------------
        inf_start = time.time()

        with torch.no_grad():
            logits = self.model(img_tensor)

        inf_end = time.time()

        # --------------------------------
        # Postprocesamiento
        # --------------------------------
        post_start = time.time()

        probabilities = torch.nn.functional.softmax(logits[0], dim=0)
        top5_prob, top5_catid = torch.topk(probabilities, 5)

        detections = []
        for i in range(5):
            det = model_pb2.Detection(
                className=IMAGENET_CLASSES[top5_catid[i]],
                confidence=float(top5_prob[i]),
                x_min=0, y_min=0,
                x_max=0, y_max=0,
                x_center=0, y_center=0,
                width=0, height=0,
                normalized=True
            )
            detections.append(det)

        post_end = time.time()

        total_end = time.time()

        # --------------------------------
        # Métricas
        # --------------------------------
        metrics = model_pb2.PerformanceMetrics(
            preprocessMs=(pre_end - pre_start) * 1000,
            inferenceMs=(inf_end - inf_start) * 1000,
            postprocessMs=(post_end - post_start) * 1000,
            totalMs=(total_end - total_start) * 1000
        )

        model_info = model_pb2.ModelInfo(
            modelName="resnet50",
            modelVersion="imagenet",
            device=self.device
        )

        image_info = model_pb2.ImageInfo(
            width=w,
            height=h
        )

        # --------------------------------
        # RESPUESTA FINAL
        # --------------------------------
        return model_pb2.ModelResponse(
            modelInfo=model_info,
            imageInfo=image_info,
            metrics=metrics,
            detections=detections
        )


# ================================
#   Servidor gRPC
# ================================
def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    model_pb2_grpc.add_ModelServiceServicer_to_server(ModelService(), server)
    server.add_insecure_port("[::]:50062")
    server.start()
    print("[gRPC] ResNet50 server running on port 50062")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
