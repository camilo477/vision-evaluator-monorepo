import grpc
from concurrent import futures
import time
import model_pb2
import model_pb2_grpc
import cv2
import numpy as np
import torch


class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Loading YOLOv5n...")
        self.model = torch.hub.load(
            "ultralytics/yolov5", "yolov5n", pretrained=True)
        self.device = "cpu"
        print("[MODEL] YOLOv5n loaded on CPU")

    def ProcessImage(self, request, context):

        total_start = time.time()

        # --- Preprocesamiento ---
        pre_start = time.time()
        nparr = np.frombuffer(request.imageBuffer, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        pre_end = time.time()

        if img is None:
            context.set_details("Error decodificando imagen")
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            return model_pb2.ModelResponse()

        h, w = img.shape[:2]

        # --- Inferencia ---
        inf_start = time.time()
        results = self.model(img)
        # tensor Nx6: [x1, y1, x2, y2, conf, cls]
        detections_list = results.xyxy[0]
        inf_end = time.time()

        # --- Postproceso ---
        post_start = time.time()
        detections = []

        for *xyxy, conf, cls in detections_list.tolist():
            x1, y1, x2, y2 = map(float, xyxy)
            conf = float(conf)
            cls = int(cls)
            cls_name = self.model.names[cls]

            det = model_pb2.Detection(
                className=cls_name,
                confidence=conf,
                x_min=x1,
                y_min=y1,
                x_max=x2,
                y_max=y2,
                x_center=float((x1 + x2) / 2),
                y_center=float((y1 + y2) / 2),
                width=float(x2 - x1),
                height=float(y2 - y1),
                normalized=False
            )
            detections.append(det)

        post_end = time.time()

        total_end = time.time()

        # --- Métricas ---
        metrics = model_pb2.PerformanceMetrics(
            preprocessMs=(pre_end - pre_start) * 1000,
            inferenceMs=(inf_end - inf_start) * 1000,
            postprocessMs=(post_end - post_start) * 1000,
            totalMs=(total_end - total_start) * 1000
        )

        # --- Info del modelo ---
        model_info = model_pb2.ModelInfo(
            modelName="yolov5n",
            modelVersion="6.2",
            device=self.device
        )

        # --- Info de la imagen ---
        image_info = model_pb2.ImageInfo(
            width=w,
            height=h
        )

        return model_pb2.ModelResponse(
            modelInfo=model_info,
            imageInfo=image_info,
            metrics=metrics,
            detections=detections
        )


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    model_pb2_grpc.add_ModelServiceServicer_to_server(
        ModelService(), server
    )
    server.add_insecure_port("[::]:50052")
    server.start()
    print("[gRPC] Servidor iniciado en puerto 50052")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
