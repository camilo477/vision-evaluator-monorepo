# ZBar Model Service

Microservicio gRPC para lectura de codigos QR y codigos de barras con ZBar via `pyzbar`.

Puerto: `localhost:50059`

## Dependencia del sistema

Ademas de `requirements.txt`, instala ZBar:

```bash
sudo apt install libzbar0
```

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
