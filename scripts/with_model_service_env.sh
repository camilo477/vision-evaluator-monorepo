#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <service-dir> <command> [args...]" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="$1"
shift
SERVICE_DIR="$ROOT_DIR/$SERVICE_NAME"

if [ ! -d "$SERVICE_DIR" ]; then
  echo "Service directory not found: $SERVICE_DIR" >&2
  exit 1
fi

CACHE_DIR="$SERVICE_DIR/.cache"
mkdir -p \
  "$CACHE_DIR/home" \
  "$CACHE_DIR/xdg-config" \
  "$CACHE_DIR/xdg-cache" \
  "$CACHE_DIR/matplotlib" \
  "$CACHE_DIR/paddlex" \
  "$CACHE_DIR/paddle" \
  "$CACHE_DIR/torch" \
  "$CACHE_DIR/ultralytics" \
  "$CACHE_DIR/huggingface"

export HOME="$CACHE_DIR/home"
export XDG_CONFIG_HOME="$CACHE_DIR/xdg-config"
export XDG_CACHE_HOME="$CACHE_DIR/xdg-cache"
export MPLCONFIGDIR="$CACHE_DIR/matplotlib"
export PADDLE_PDX_CACHE_HOME="$CACHE_DIR/paddlex"
export PADDLE_HOME="$CACHE_DIR/paddle"
export TORCH_HOME="$CACHE_DIR/torch"
export YOLO_CONFIG_DIR="$CACHE_DIR/ultralytics"
export HF_HOME="$CACHE_DIR/huggingface"
export PYTHONUNBUFFERED=1
export TF_USE_LEGACY_KERAS=1

cd "$SERVICE_DIR"
exec "$@"
