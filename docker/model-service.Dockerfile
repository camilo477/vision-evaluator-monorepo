FROM python:3.10-slim

ARG SERVICE_DIR

ENV PYTHONUNBUFFERED=1 \
    TF_USE_LEGACY_KERAS=1 \
    XDG_CONFIG_HOME=/app/.cache/xdg-config \
    XDG_CACHE_HOME=/app/.cache/xdg-cache \
    MPLCONFIGDIR=/app/.cache/matplotlib \
    PADDLE_PDX_CACHE_HOME=/app/.cache/paddlex \
    PADDLE_HOME=/app/.cache/paddle \
    TORCH_HOME=/app/.cache/torch \
    YOLO_CONFIG_DIR=/app/.cache/ultralytics \
    HF_HOME=/app/.cache/huggingface

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      default-jre-headless \
      libgl1 \
      libglib2.0-0 \
      libzbar0 \
      tesseract-ocr \
      tesseract-ocr-eng \
      tesseract-ocr-spa \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ${SERVICE_DIR}/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /tmp/requirements.txt

COPY ${SERVICE_DIR}/ /app/

RUN mkdir -p \
    /app/.cache/xdg-config \
    /app/.cache/xdg-cache \
    /app/.cache/matplotlib \
    /app/.cache/paddlex \
    /app/.cache/paddle \
    /app/.cache/torch \
    /app/.cache/ultralytics \
    /app/.cache/huggingface

CMD ["python", "server.py"]
