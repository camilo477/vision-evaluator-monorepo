import io
import time
from concurrent import futures

import grpc
import model_pb2
import model_pb2_grpc
import torch
from PIL import Image
from torchvision import models


class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Loading MobileNetV3 Small (ImageNet)...")
        weights = models.MobileNet_V3_Small_Weights.DEFAULT
        self.model = models.mobilenet_v3_small(weights=weights)
        self.model.eval()
        self.transform = weights.transforms()
        self.categories = weights.meta["categories"]
        self.device = "cpu"
        print("[MODEL] MobileNetV3 Small loaded on CPU")

    def ProcessImage(self, request, context):
        total_start = time.time()

        pre_start = time.time()
        try:
            image = Image.open(io.BytesIO(request.imageBuffer)).convert("RGB")
        except Exception:
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details("Error leyendo la imagen")
            return model_pb2.ModelResponse()

        width, height = image.size
        tensor = self.transform(image).unsqueeze(0)
        pre_end = time.time()

        inf_start = time.time()
        with torch.no_grad():
            logits = self.model(tensor)
        inf_end = time.time()

        post_start = time.time()
        probabilities = torch.nn.functional.softmax(logits[0], dim=0)
        top_prob, top_catid = torch.topk(probabilities, 5)
        detections = []

        for i in range(len(top_prob)):
            detections.append(model_pb2.Detection(
                className=self.categories[int(top_catid[i])],
                confidence=float(top_prob[i]),
                x_min=0,
                y_min=0,
                x_max=0,
                y_max=0,
                x_center=0,
                y_center=0,
                width=0,
                height=0,
                normalized=True,
            ))
        post_end = time.time()

        total_end = time.time()
        return model_pb2.ModelResponse(
            modelInfo=model_pb2.ModelInfo(
                modelName="MobileNet",
                modelVersion="mobilenet_v3_small_imagenet",
                device=self.device,
            ),
            imageInfo=model_pb2.ImageInfo(width=width, height=height),
            metrics=model_pb2.PerformanceMetrics(
                preprocessMs=(pre_end - pre_start) * 1000,
                inferenceMs=(inf_end - inf_start) * 1000,
                postprocessMs=(post_end - post_start) * 1000,
                totalMs=(total_end - total_start) * 1000,
            ),
            detections=detections,
        )


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    model_pb2_grpc.add_ModelServiceServicer_to_server(ModelService(), server)
    server.add_insecure_port("[::]:50054")
    server.start()
    print("[gRPC] MobileNet server running on port 50054")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
