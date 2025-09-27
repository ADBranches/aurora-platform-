# Base logging configuration for all microservices
import structlog
import logging
import json
import time
from prometheus_client import Counter, Histogram, generate_latest

# Configure structured logging
def configure_logging(service_name: str):
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    
    log = structlog.get_logger(service_name)
    return log

# Base metrics for all services
class BaseMetrics:
    def __init__(self, service_name: str):
        self.requests_total = Counter(f'{service_name}_requests_total', 
                                     'Total requests', ['method', 'endpoint', 'status'])
        self.request_duration = Histogram(f'{service_name}_request_duration_seconds',
                                        'Request duration in seconds', ['method', 'endpoint'])
        self.errors_total = Counter(f'{service_name}_errors_total',
                                  'Total errors', ['error_type'])
    
    def track_request(self, method: str, endpoint: str, status: int, duration: float):
        self.requests_total.labels(method=method, endpoint=endpoint, status=status).inc()
        self.request_duration.labels(method=method, endpoint=endpoint).observe(duration)
