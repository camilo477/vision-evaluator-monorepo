#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_SERVICES=(
  yolo-model-service-a
  eco-modelo-yolov5n
  eco-model-efficientdet
  mobilenet-model-service
  resnet-model-service-b
  paddleocr-model-service
  easyocr-model-service
  tesseract-model-service
  craftcrnn-model-service
  zbar-model-service
  zxing-model-service
  pybarcode-model-service
)

if [ "$#" -gt 0 ]; then
  SERVICES=("$@")
else
  SERVICES=("${DEFAULT_SERVICES[@]}")
fi

for service in "${SERVICES[@]}"; do
  service_dir="$ROOT_DIR/$service"
  if [ ! -d "$service_dir" ]; then
    echo "Skipping missing service: $service" >&2
    continue
  fi

  if [ ! -x "$service_dir/env/bin/python" ]; then
    python3 -m venv "$service_dir/env"
  fi

  "$service_dir/env/bin/pip" install -r "$service_dir/requirements.txt"

  if [ -f "$service_dir/model.proto" ]; then
    (
      cd "$service_dir"
      env/bin/python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. model.proto
    )
  fi
done
