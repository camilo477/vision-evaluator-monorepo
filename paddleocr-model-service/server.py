import time
from concurrent import futures

import cv2
import grpc
import model_pb2
import model_pb2_grpc
import numpy as np
from paddleocr import PaddleOCR


def _bbox_from_points(points):
    xs = [float(p[0]) for p in points]
    ys = [float(p[1]) for p in points]
    x_min, x_max = min(xs), max(xs)
    y_min, y_max = min(ys), max(ys)
    return x_min, y_min, x_max, y_max


class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Loading PaddleOCR...")
        self.ocr = PaddleOCR(
            use_textline_orientation=True,
            lang="en",
            enable_mkldnn=False,
        )
        self.device = "cpu"
        print("[MODEL] PaddleOCR loaded")

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
        result = self.ocr.predict(img, use_textline_orientation=True)
        inf_end = time.time()

        post_start = time.time()
        detections = self._parse_result(result)
        post_end = time.time()
        total_end = time.time()

        return model_pb2.ModelResponse(
            modelInfo=model_pb2.ModelInfo(
                modelName="PaddleOCR",
                modelVersion="paddleocr",
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

    def _parse_result(self, result):
        detections = []

        for page in result or []:
            if isinstance(page, dict):
                texts = page.get("rec_texts") or []
                scores = page.get("rec_scores") or []
                polygons = page.get("rec_polys") or page.get("dt_polys") or []
                boxes = page.get("rec_boxes")

                for index, text in enumerate(texts):
                    if not str(text).strip():
                        continue

                    confidence = float(scores[index]) if index < len(scores) else 0.0
                    if index < len(polygons):
                        x_min, y_min, x_max, y_max = _bbox_from_points(polygons[index])
                    elif boxes is not None and index < len(boxes):
                        x_min, y_min, x_max, y_max = [float(v) for v in boxes[index]]
                    else:
                        x_min = y_min = x_max = y_max = 0.0

                    detections.append(self._detection(str(text), confidence, x_min, y_min, x_max, y_max))
                continue

            lines = page if page else []
            for line in lines:
                points = line[0]
                text, confidence = line[1]
                x_min, y_min, x_max, y_max = _bbox_from_points(points)
                detections.append(self._detection(str(text), float(confidence), x_min, y_min, x_max, y_max))

        return detections

    def _detection(self, text, confidence, x_min, y_min, x_max, y_max):
        return model_pb2.Detection(
            className=text,
            confidence=confidence,
            x_min=x_min,
            y_min=y_min,
            x_max=x_max,
            y_max=y_max,
            x_center=(x_min + x_max) / 2,
            y_center=(y_min + y_max) / 2,
            width=x_max - x_min,
            height=y_max - y_min,
            normalized=False,
        )


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    model_pb2_grpc.add_ModelServiceServicer_to_server(ModelService(), server)
    server.add_insecure_port("[::]:50055")
    server.start()
    print("[gRPC] PaddleOCR server running on port 50055")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
