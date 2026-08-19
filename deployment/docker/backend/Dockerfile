FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    fastapi==0.141.1 \
    uvicorn==0.52.3 \
    sqlalchemy==2.0.52 \
    asyncpg==0.31.0 \
    alembic==1.19.1 \
    pydantic==2.13.4 \
    pydantic-settings==2.15.0 \
    qdrant-client==1.19.0 \
    PyJWT==2.13.0 \
    aiofiles==25.1.0 \
    httpx==0.28.1 \
    python-dotenv==1.2.2 \
    python-json-logger==4.1.0 \
    PyYAML==6.0.3 \
    sentence-transformers==2.5.0 \
    starlette==1.6.0

COPY . .

EXPOSE 5001

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5001", "--log-level", "info"]
