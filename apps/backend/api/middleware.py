from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
import time
import uuid
from config.settings import settings
from config.logger import logger, set_log_context
from services.metrics import metrics_service

class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        correlation_id = request.headers.get("X-Correlation-ID") or str(uuid.uuid4())
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        set_log_context(
            correlation_id=correlation_id,
            request_id=request_id,
            path=request.url.path,
            method=request.method
        )
        response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id
        response.headers["X-Request-ID"] = request_id
        return response

class MetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        try:
            response = await call_next(request)
            duration = time.time() - start_time
            metrics_service.record_request(
                method=request.method,
                endpoint=request.url.path,
                status=response.status_code,
                duration=duration
            )
            return response
        except Exception as e:
            duration = time.time() - start_time
            metrics_service.record_request(
                method=request.method,
                endpoint=request.url.path,
                status=500,
                duration=duration
            )
            raise

def setup_middleware(app: FastAPI):
    app.add_middleware(CORSMiddleware, allow_origins=settings.CORS_ORIGINS, allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
    app.add_middleware(RequestContextMiddleware)
    app.add_middleware(MetricsMiddleware)
