#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SERVICES=(
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

for service in "${SERVICES[@]}"; do
  printf '\n== %s ==\n' "$service"
  if [ ! -x "$ROOT_DIR/$service/env/bin/python" ]; then
    echo "missing env/bin/python"
    exit 1
  fi

  "$ROOT_DIR/scripts/with_model_service_env.sh" \
    "$service" \
    env/bin/python \
    -c "import server; print('import ok')"
done
