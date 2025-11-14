import os
import logging
from contextlib import asynccontextmanager
from typing import Dict, Any

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import make_asgi_app

try:
    from api.core.config import settings
    from api.core.logging import setup_logging
    from api.routes import health, predictions, metrics
except ImportError as e:
    logging.error(f"Failed to import modules: {e}")
    raise

# Setup structured logging
logger = logging.getLogger(__name__)

try:
    setup_logging()
except Exception as e:
    logging.warning(f"Failed to setup structured logging, using default: {e}")
    logging.basicConfig(level=logging.INFO)


# Global exception handler
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Handle uncaught exceptions globally."""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Internal server error",
            "path": str(request.url),
        },
    )


# Lifespan manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application startup and shutdown."""
    logger.info("Starting application...")
    try:
        from api.core.container import Container
        container = Container()
        await container.start()
        logger.info("Application started successfully")
        yield
    except Exception as e:
        logger.error(f"Failed to start application: {e}", exc_info=True)
        raise
    finally:
        logger.info("Shutting down application...")
        try:
            await container.stop()
            logger.info("Application stopped successfully")
        except Exception as e:
            logger.error(f"Error during shutdown: {e}", exc_info=True)


# FastAPI app
app = FastAPI(
    title="K8s Anomaly Detection API",
    version="0.1.0",
    description="ML-powered predictive anomaly detection for Kubernetes workloads",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add global exception handler
app.add_exception_handler(Exception, global_exception_handler)

# Include routers
try:
    app.include_router(health.router, tags=["Health"])
    app.include_router(predictions.router, prefix="/api/v1", tags=["Predictions"])
    app.include_router(metrics.router, prefix="/api/v1", tags=["Metrics"])
    logger.info("Routes registered successfully")
except Exception as e:
    logger.error(f"Failed to register routes: {e}", exc_info=True)
    raise

# Mount Prometheus metrics endpoint
try:
    metrics_app = make_asgi_app()
    app.mount("/metrics", metrics_app)
    logger.info("Prometheus metrics endpoint mounted at /metrics")
except Exception as e:
    logger.error(f"Failed to mount metrics endpoint: {e}", exc_info=True)


@app.get("/", tags=["Root"])
async def root() -> Dict[str, Any]:
    """Root endpoint with API information."""
    return {
        "name": "K8s Anomaly Detection API",
        "version": "0.1.0",
        "status": "running",
        "docs": "/docs",
        "health": "/health/live",
    }