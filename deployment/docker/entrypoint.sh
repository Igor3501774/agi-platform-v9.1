#!/bin/bash
set -e

echo "=========================================="
echo "  AGI Platform v9.0 - Starting..."
echo "=========================================="

echo "Starting FastAPI application..."
exec uvicorn backend.main:app --host 0.0.0.0 --port ${PORT:-8000}