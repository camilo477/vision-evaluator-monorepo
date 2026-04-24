# CRAFTCRNN Model Service

Microservicio gRPC para deteccion y reconocimiento de texto usando `keras-ocr`, que combina deteccion tipo CRAFT con reconocimiento tipo CRNN.

Puerto: `localhost:50058`

## Uso

```bash
python -m venv env
source env/bin/activate
pip install -r requirements.txt
python server.py
```

Este servicio descarga pesos la primera vez que inicia.

Si cambias `model.proto`, regenera los stubs:

```bash
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. model.proto
```
