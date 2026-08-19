import logging.config
from contextvars import ContextVar
from datetime import datetime
from typing import Dict, Any
from pythonjsonlogger import jsonlogger

_log_context: ContextVar[Dict[str, str]] = ContextVar('log_context', default={})

def set_log_context(**kwargs):
    context = _log_context.get().copy()
    context.update({k: v for k, v in kwargs.items() if v is not None})
    _log_context.set(context)

def get_log_context() -> Dict[str, str]:
    return _log_context.get()

class ContextAwareJsonFormatter(jsonlogger.JsonFormatter):
    def add_fields(self, log_record: Dict[str, Any], record: logging.LogRecord, message_dict: Dict[str, Any]):
        super().add_fields(log_record, record, message_dict)
        context = get_log_context()
        if context:
            for key, value in context.items():
                log_record[f"ctx_{key}"] = value
        log_record['timestamp'] = datetime.utcnow().isoformat()
        log_record['level'] = record.levelname
        log_record['logger'] = record.name

LOGGING_CONFIG: Dict[str, Any] = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "json": {
            "()": ContextAwareJsonFormatter,
            "format": "%(asctime)s %(levelname)s %(name)s %(message)s"
        }
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "json",
            "stream": "ext://sys.stdout"
        }
    },
    "root": {"level": "INFO", "handlers": ["console"]},
    "loggers": {
        "uvicorn": {"level": "WARNING"},
        "alembic": {"level": "INFO"}
    }
}

logging.config.dictConfig(LOGGING_CONFIG)
logger = logging.getLogger("AGI_Platform")
