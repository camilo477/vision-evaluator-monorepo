# YOLO Model Service A (gRPC)

Microservicio en Python que ejecuta **YOLOv5** para detección de objetos
y expone un servidor **gRPC** compatible con el contrato `model.proto`.

Este servicio es consumido por el orquestador `eco-api` (NestJS).

---

- Python 3.10+
- pip
- Virtualenv recomendado
- gRPC para Python (`grpcio`, `grpcio-tools`)
- torch YOLOv5

---

```
python -m venv env
source env/bin/activate
pip install -r requirements.txt
```

---

Cada vez que clones el repositorio o modifiques `model.proto`, debes regenerar los archivos:

```
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. model.proto
```

Esto crea:

- `model_pb2.py`
- `model_pb2_grpc.py`

> Estos archivos están ignorados en `.gitignore`
> porque son generados automáticamente.

---

```
python server.py
```

Salida esperada:

```
[MODEL] Cargando modelo YOLO...
[MODEL] Modelo cargado en cpu
[gRPC] Servidor iniciado en puerto 50051
```

---

El servidor expone gRPC en:

```
localhost:50052
```

---

Este servicio implementa exactamente:

```
service ModelService {
  rpc ProcessImage (ImageRequest) returns (ModelResponse);
}
```

Ver el archivo `model.proto` para todos los campos:

- `modelInfo`
- `imageInfo`
- `metrics`
- `detections[]`

---

```
server.py
model.proto
requirements.txt
README.md
env/ (ignorado)
model_pb2.py (generado)
model_pb2_grpc.py (generado)
```

<!-- ---


- Puedes cambiar el modelo YOLO (n, s, m, l, custom) editando:

```
self.model = YOLO("yolov5n.pt")
```

- Si usas modelos pesados, **NO** los subas al repo (están ignorados por default).
- `test.jpg` es opcional para pruebas desde NestJS. -->

---

Microservicio Python para detección avanzada con YOLOv5 y gRPC.
