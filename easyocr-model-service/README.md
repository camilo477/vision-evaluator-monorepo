# EasyOCR Model Service

Microservicio gRPC para reconocimiento de texto con EasyOCR.

Puerto: `localhost:50056`

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
