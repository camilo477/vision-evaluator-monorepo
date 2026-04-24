import time
from concurrent import futures

import cv2
import grpc
import model_pb2
import model_pb2_grpc
import numpy as np


class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Loading OpenCV barcode reader for pybarcode slot...")
        self.qr_detector = cv2.QRCodeDetector()
        self.barcode_detector = cv2.barcode.BarcodeDetector() if hasattr(cv2, "barcode") else None
        self.device = "cpu"
        print("[MODEL] OpenCV barcode reader ready")

    def ProcessImage(self, request, context):
        total_start = time.time()

        pre_start = time.time()
        nparr = np.frombuffer(request.imageBuffer, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        pre_end = time.time()

        if img is None:
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details("Error decodificando imagen")
            return model_pb2.ModelResponse()

        h, w = img.shape[:2]

        inf_start = time.time()
        detections_data = []

        ok, decoded_info, points, _ = self.qr_detector.detectAndDecodeMulti(img)
        if ok and points is not None:
            for text, polygon in zip(decoded_info, points):
                if text:
                    detections_data.append(("QR_CODE", text, polygon))

        if self.barcode_detector is not None:
            try:
                ok, decoded_info, decoded_type, points = self.barcode_detector.detectAndDecode(img)
                if ok and points is not None:
                    for text, barcode_type, polygon in zip(decoded_info, decoded_type, points):
                        if text:
                            detections_data.append((str(barcode_type), text, polygon))
            except Exception:
                pass
        inf_end = time.time()

        post_start = time.time()
        detections = []
        for code_type, text, polygon in detections_data:
            xs = [float(p[0]) for p in polygon]
            ys = [float(p[1]) for p in polygon]
            x_min, x_max = min(xs), max(xs)
            y_min, y_max = min(ys), max(ys)
            width = x_max - x_min
            height = y_max - y_min
            detections.append(model_pb2.Detection(
                className=f"{code_type}: {text}",
                confidence=1.0,
                x_min=x_min,
                y_min=y_min,
                x_max=x_max,
                y_max=y_max,
                x_center=x_min + width / 2,
                y_center=y_min + height / 2,
                width=width,
                height=height,
                normalized=False,
            ))
        post_end = time.time()
        total_end = time.time()

        return model_pb2.ModelResponse(
            modelInfo=model_pb2.ModelInfo(
                modelName="pybarcode",
                modelVersion="opencv-barcode",
                device=self.device,
            ),
            imageInfo=model_pb2.ImageInfo(width=w, height=h),
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
    server.add_insecure_port("[::]:50061")
    server.start()
    print("[gRPC] pybarcode-compatible server running on port 50061")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
