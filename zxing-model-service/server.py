import time
from concurrent import futures

import cv2
import grpc
import model_pb2
import model_pb2_grpc
import numpy as np
import zxingcpp


def _position_bounds(position):
    points = [
        getattr(position, "top_left", None),
        getattr(position, "top_right", None),
        getattr(position, "bottom_right", None),
        getattr(position, "bottom_left", None),
    ]
    points = [p for p in points if p is not None]
    if not points:
        return 0, 0, 0, 0
    xs = [float(getattr(p, "x", 0)) for p in points]
    ys = [float(getattr(p, "y", 0)) for p in points]
    return min(xs), min(ys), max(xs), max(ys)


class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Loading ZXing...")
        self.device = "cpu"
        print("[MODEL] ZXing ready")

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
        barcodes = zxingcpp.read_barcodes(img)
        inf_end = time.time()

        post_start = time.time()
        detections = []
        for barcode in barcodes:
            x_min, y_min, x_max, y_max = _position_bounds(
                getattr(barcode, "position", None)
            )
            text = getattr(barcode, "text", "")
            fmt = getattr(barcode, "format", "unknown")
            width = x_max - x_min
            height = y_max - y_min
            detections.append(model_pb2.Detection(
                className=f"{fmt}: {text}",
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
                modelName="ZXing",
                modelVersion="zxing-cpp",
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
    server.add_insecure_port("[::]:50060")
    server.start()
    print("[gRPC] ZXing server running on port 50060")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
