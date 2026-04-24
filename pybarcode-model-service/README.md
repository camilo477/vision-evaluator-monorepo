# pybarcode-Compatible Model Service

Microservicio gRPC para ocupar la entrada `pybarcode` declarada en NestJS.

Nota: `pybarcode` es una libreria para generar codigos de barras, no para leerlos. Por eso este servicio usa detectores de OpenCV para lectura de QR/codigos cuando estan disponibles.

Puerto: `localhost:50061`

## Uso

```bash
python -m venv env
source env/bin/activate
pip install -r requirements.txt
python server.py
```

Si cambias `model.proto`, regenera los stubs:

```bash
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. model.proto
```
