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

PORTS=(
  50051
  50052
  50053
  50054
  50062
  50055
  50056
  50057
  50058
  50059
  50060
  50061
)

PIDS=()

cleanup() {
  if [ "${#PIDS[@]}" -gt 0 ]; then
    kill "${PIDS[@]}" 2>/dev/null || true
    wait "${PIDS[@]}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

for service in "${SERVICES[@]}"; do
  log_dir="$ROOT_DIR/$service/.cache/logs"
  mkdir -p "$log_dir"
  echo "Starting $service -> $log_dir/service.log"
  "$ROOT_DIR/scripts/run_model_service.sh" "$service" >"$log_dir/service.log" 2>&1 &
  PIDS+=("$!")
done

echo "Started ${#PIDS[@]} model services. Waiting for ports..."

ready_count=0
declare -a READY
deadline=$((SECONDS + ${MODEL_START_TIMEOUT:-900}))

while [ "$ready_count" -lt "${#SERVICES[@]}" ] && [ "$SECONDS" -lt "$deadline" ]; do
  for i in "${!SERVICES[@]}"; do
    if [ "${READY[$i]:-0}" = "1" ]; then
      continue
    fi

    service="${SERVICES[$i]}"
    port="${PORTS[$i]}"
    log_file="$ROOT_DIR/$service/.cache/logs/service.log"

    if (: >"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1; then
      READY[$i]=1
      ready_count=$((ready_count + 1))
      echo "OK $service on port $port"
      continue
    fi

    if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
      READY[$i]=1
      ready_count=$((ready_count + 1))
      echo "FAILED $service before opening port $port. See $log_file"
    fi
  done

  if [ "$ready_count" -lt "${#SERVICES[@]}" ]; then
    sleep 2
  fi
done

if [ "$ready_count" -lt "${#SERVICES[@]}" ]; then
  echo "Some services are still loading. Check their logs under <service>/.cache/logs/service.log"
fi

echo "Press Ctrl+C to stop all model services."
wait
