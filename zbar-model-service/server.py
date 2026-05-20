import io
import time
from concurrent import futures

import cv2
import grpc
import model_pb2
import model_pb2_grpc
import numpy as np
from PIL import Image

try:
    from pyzbar.pyzbar import decode as zbar_decode
    ZBAR_IMPORT_ERROR = None
except ImportError as exc:
    zbar_decode = None
    ZBAR_IMPORT_ERROR = exc


class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Loading ZBar...")
        self.qr_detector = cv2.QRCodeDetector()
        self.device = "cpu"
        if zbar_decode is None:
            print(f"[MODEL] ZBar unavailable, using OpenCV QR fallback: {ZBAR_IMPORT_ERROR}")
        else:
            print("[MODEL] ZBar ready")

    def ProcessImage(self, request, context):
        total_start = time.time()

        pre_start = time.time()
        try:
            image = Image.open(io.BytesIO(request.imageBuffer)).convert("RGB")
        except Exception:
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details("Error leyendo la imagen")
            return model_pb2.ModelResponse()
        w, h = image.size
        pre_end = time.time()

        inf_start = time.time()
        symbols = zbar_decode(image) if zbar_decode is not None else []
        fallback_codes = []
        if zbar_decode is None:
            img = np.array(image)
            ok, decoded_info, points, _ = self.qr_detector.detectAndDecodeMulti(img)
            if ok and points is not None:
                for text, polygon in zip(decoded_info, points):
                    if text:
                        fallback_codes.append(("QR_CODE", text, polygon))
        inf_end = time.time()

        post_start = time.time()
        detections = []
        for symbol in symbols:
            rect = symbol.rect
            text = symbol.data.decode("utf-8", errors="replace")
            confidence = float(getattr(symbol, "quality", 100) or 100) / 100
            x = float(rect.left)
            y = float(rect.top)
            box_w = float(rect.width)
            box_h = float(rect.height)
            detections.append(model_pb2.Detection(
                className=f"{symbol.type}: {text}",
                confidence=confidence,
                x_min=x,
                y_min=y,
                x_max=x + box_w,
                y_max=y + box_h,
                x_center=x + box_w / 2,
                y_center=y + box_h / 2,
                width=box_w,
                height=box_h,
                normalized=False,
            ))
        for code_type, text, polygon in fallback_codes:
            xs = [float(p[0]) for p in polygon]
            ys = [float(p[1]) for p in polygon]
            x_min, x_max = min(xs), max(xs)
            y_min, y_max = min(ys), max(ys)
            box_w = x_max - x_min
            box_h = y_max - y_min
            detections.append(model_pb2.Detection(
                className=f"{code_type}: {text}",
                confidence=1.0,
                x_min=x_min,
                y_min=y_min,
                x_max=x_max,
                y_max=y_max,
                x_center=x_min + box_w / 2,
                y_center=y_min + box_h / 2,
                width=box_w,
                height=box_h,
                normalized=False,
            ))
        post_end = time.time()
        total_end = time.time()

        return model_pb2.ModelResponse(
            modelInfo=model_pb2.ModelInfo(
                modelName="ZBar",
                modelVersion="pyzbar" if zbar_decode is not None else "opencv-qr-fallback",
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
    server.add_insecure_port("[::]:50059")
    server.start()
    print("[gRPC] ZBar server running on port 50059")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
