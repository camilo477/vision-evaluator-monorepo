#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <service-dir>" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="$1"
SERVICE_DIR="$ROOT_DIR/$SERVICE_NAME"

if [ ! -x "$SERVICE_DIR/env/bin/python" ]; then
  echo "Python env not found for $SERVICE_NAME. Run: scripts/setup_model_envs.sh $SERVICE_NAME" >&2
  exit 1
fi

exec "$ROOT_DIR/scripts/with_model_service_env.sh" "$SERVICE_NAME" env/bin/python server.py
