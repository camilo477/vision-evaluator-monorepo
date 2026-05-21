# Docker

Este proyecto puede levantarse completo con Docker Compose:

- 12 microservicios Python gRPC de modelos
- Backend NestJS en el puerto `3000`
- Frontend Flutter Web servido con Nginx en el puerto `8080`

## Configurar URL del backend para el front

El frontend se compila con la URL del backend. Para probar desde celular, usa la IP local del PC:

```bash
cp .env.docker.example .env
```

Edita `.env` si tu IP cambio:

```env
API_BASE_URL=http://192.168.10.48:3000
```

Para probar solo desde el mismo PC tambien puedes usar:

```env
API_BASE_URL=http://localhost:3000
```

## Levantar todo

Desde la raiz del proyecto:

```bash
docker-compose up --build
```

Abrir:

- PC: `http://localhost:8080`
- Celular en la misma red: `http://192.168.10.48:8080`
- API: `http://localhost:3000/image/models`
- Docs API: `http://localhost:3000/docs`

## Detener

```bash
docker-compose down
```

## Reconstruir si cambias el front o el backend

```bash
docker-compose up --build
```

La primera construccion puede tardar bastante porque descarga dependencias pesadas como PyTorch, TensorFlow, PaddleOCR y Flutter.
