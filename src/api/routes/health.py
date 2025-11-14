"""Health check endpoints."""
import logging
from typing import Dict, Any
from fastapi import APIRouter, status
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/health")


@router.get("/live", status_code=status.HTTP_200_OK)
async def liveness() -> Dict[str, str]:
    """
    Liveness probe endpoint.
    
    Returns 200 if the application is running.
    Used by Kubernetes to determine if the pod should be restarted.
    """
    return {"status": "alive"}


@router.get("/ready", status_code=status.HTTP_200_OK)
async def readiness() -> JSONResponse:
    """
    Readiness probe endpoint.
    
    Returns 200 if the application is ready to serve traffic.
    Used by Kubernetes to determine if the pod should receive traffic.
    """
    try:
        # Check if critical components are ready
        from api.core.container import get_container
        
        try:
            container = get_container()
            detector = container.get_detector()
            
            # Check if model is loaded
            if not detector.health():
                logger.warning("Readiness check failed: model not loaded")
                return JSONResponse(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    content={
                        "status": "not_ready",
                        "reason": "model_not_loaded"
                    }
                )
            
            return JSONResponse(
                status_code=status.HTTP_200_OK,
                content={
                    "status": "ready",
                    "model_info": detector.get_info()
                }
            )
            
        except RuntimeError as e:
            logger.warning(f"Readiness check failed: {e}")
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={
                    "status": "not_ready",
                    "reason": "container_not_initialized"
                }
            )
            
    except Exception as e:
        logger.error(f"Readiness check error: {e}", exc_info=True)
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "not_ready",
                "reason": str(e)
            }
        )


@router.get("/startup", status_code=status.HTTP_200_OK)
async def startup() -> Dict[str, str]:
    """
    Startup probe endpoint.
    
    Returns 200 when the application has completed startup.
    Used by Kubernetes to determine when to start liveness/readiness probes.
    """
    return {"status": "started"}
