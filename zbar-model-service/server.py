import io
import time
from concurrent import futures

import grpc
import model_pb2
import model_pb2_grpc
from PIL import Image
from pyzbar.pyzbar import decode


class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Loading ZBar...")
        self.device = "cpu"
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
        symbols = decode(image)
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
        post_end = time.time()
        total_end = time.time()

        return model_pb2.ModelResponse(
            modelInfo=model_pb2.ModelInfo(
                modelName="ZBar",
                modelVersion="pyzbar",
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
