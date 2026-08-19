FROM python:3.11-slim

RUN apt-get update && apt-get install -y gcc postgresql-client && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY apps/backend/requirements/base.txt .
RUN pip install --no-cache-dir -r base.txt

COPY apps/backend/ .

ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5001", "--workers", "5"]
