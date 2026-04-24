import grpc
from concurrent import futures
import time
import model_pb2
import model_pb2_grpc
from ultralytics import YOLO
import cv2
import numpy as np
import psutil

class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Cargando modelo YOLO...")
        self.model = YOLO("yolov8n.pt")
        self.device = "cpu"
        print("[MODEL] Modelo cargado en CPU")

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
        results = self.model(img, conf=request.minConfidence or 0.25)[0]
        inf_end = time.time()

        # --- Postproceso ---
        post_start = time.time()
        detections = []

        for box in results.boxes:
            x1, y1, x2, y2 = map(float, box.xyxy[0])
            conf = float(box.conf[0])
            cls = int(box.cls[0])
            cls_name = self.model.names[cls]

            det = model_pb2.Detection(
                className=cls_name,
                confidence=conf,
                x_min=x1,
                y_min=y1,
                x_max=x2,
                y_max=y2,
                x_center=float((x1+x2)/2),
                y_center=float((y1+y2)/2),
                width=float(x2-x1),
                height=float(y2-y1),
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
            modelName="yolov8n",
            modelVersion="8.3.1",
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
    server.add_insecure_port("[::]:50051")
    server.start()
    print("[gRPC] Servidor iniciado en puerto 50051")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
