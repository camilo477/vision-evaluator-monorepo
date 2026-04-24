import grpc
from concurrent import futures
import time
import model_pb2
import model_pb2_grpc

import cv2
import numpy as np
import torch
from PIL import Image

from effdet import create_model
from effdet.data import resolve_input_config
from effdet.data.transforms import ImageToTensor, ResizePad, resolve_fill_color


# ============================================================
#   LISTA COCO
# ============================================================
COCO_NAMES = [
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light",
    "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
    "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
    "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard",
    "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
    "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
    "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote", "keyboard",
    "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase",
    "scissors", "teddy bear", "hair drier", "toothbrush"
]


# ============================================================
#   SERVICIO EfficientDet
# ============================================================
class ModelService(model_pb2_grpc.ModelServiceServicer):
    def __init__(self):
        print("[MODEL] Loading EfficientDet-d0...")

        self.model = create_model(
            "tf_efficientdet_d0",
            bench_task="predict",
            pretrained=True,
        )

        # CPU
        self.device = torch.device("cpu")
        self.model.to(self.device)
        self.model.eval()

        self.input_config = resolve_input_config({}, model=self.model)
        self.target_size = self.input_config["input_size"][-2:]
        self.resize_pad = ResizePad(
            target_size=self.target_size,
            interpolation=self.input_config["interpolation"],
            fill_color=resolve_fill_color(
                self.input_config["fill_color"],
                self.input_config["mean"],
            ),
        )
        self.to_tensor = ImageToTensor()

        print("[MODEL] EfficientDet-d0 loaded on CPU ✓")

    # ============================================================
    #   PROCESAR IMAGEN
    # ============================================================
    def ProcessImage(self, request, context):

        total_start = time.time()

        # --- PREPROCESS ---
        pre_start = time.time()
        nparr = np.frombuffer(request.imageBuffer, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        pre_end = time.time()

        if img is None:
            context.set_details("Error decodificando imagen")
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            return model_pb2.ModelResponse()

        h, w = img.shape[:2]

        # Inference
        inf_start = time.time()
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(img_rgb)
        processed_img, image_meta = self.resize_pad(pil_img, {})
        tensor, _ = self.to_tensor(processed_img, image_meta)
        tensor = tensor.unsqueeze(0).to(self.device).float() / 255.0
        img_info = {
            "img_scale": torch.tensor(
                [image_meta["img_scale"]],
                dtype=torch.float32,
                device=self.device,
            ),
            "img_size": torch.tensor(
                [[h, w]],
                dtype=torch.float32,
                device=self.device,
            ),
        }

        with torch.no_grad():
            preds = self.model(tensor, img_info=img_info)[0].cpu().numpy()

        inf_end = time.time()

        # --- POSTPROCESS ---
        post_start = time.time()

        min_conf = request.minConfidence if request.minConfidence else 0.25
        detections = []

        for x1, y1, x2, y2, conf, cls in preds:
            conf = float(conf)

            if conf < min_conf:
                continue

            cls_idx = int(cls) - 1
            cls_name = (
                COCO_NAMES[cls_idx]
                if 0 <= cls_idx < len(COCO_NAMES)
                else str(int(cls))
            )

            detections.append(model_pb2.Detection(
                className=cls_name,
                confidence=conf,
                x_min=float(x1),
                y_min=float(y1),
                x_max=float(x2),
                y_max=float(y2),
                x_center=float((x1 + x2) / 2),
                y_center=float((y1 + y2) / 2),
                width=float(x2 - x1),
                height=float(y2 - y1),
                normalized=False
            ))

        post_end = time.time()

        total_end = time.time()

        metrics = model_pb2.PerformanceMetrics(
            preprocessMs=(pre_end - pre_start) * 1000,
            inferenceMs=(inf_end - inf_start) * 1000,
            postprocessMs=(post_end - post_start) * 1000,
            totalMs=(total_end - total_start) * 1000
        )

        model_info = model_pb2.ModelInfo(
            modelName="efficientdet-d0",
            modelVersion="1.0",
            device="cpu"
        )

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


# ============================================================
#       SERVIDOR GRPC
# ============================================================
def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    model_pb2_grpc.add_ModelServiceServicer_to_server(ModelService(), server)
    server.add_insecure_port("[::]:50053")
    server.start()
    print("[gRPC] EfficientDet server running on port 50053")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
