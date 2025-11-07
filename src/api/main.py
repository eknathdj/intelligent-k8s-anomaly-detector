import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, status
from prometheus_client import make_asgi_app

from api.core.config import settings
from api.core.logging import setup_logging
from api.routes import health, predictions, metrics

# structured logging
setup_logging()

# lifespan manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    from api.core.container import Container
    container = Container()
    await container.start()
    yield
    await container.stop()

# FastAPI app
app = FastAPI(
    title="K8s-Anomaly-API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# routes
app.include_router(health.router)
app.include_router(predictions.router, prefix="/api/v1")
app.include_router(metrics.router, prefix="/api/v1")

# /metrics for Prometheus scraping
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)