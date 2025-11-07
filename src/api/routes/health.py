from fastapi import APIRouter
from api.core.container import Container
from anomaly_detector.health_check import check_health

router = APIRouter(tags=["health"])

@router.get("/health/live", summary="Liveness probe")
async def liveness():
    return {"status": "alive"}

@router.get("/health/ready", summary="Readiness probe")
async def readiness(container: Container = Container()):  # simple singleton
    ok = check_health(container.detector)
    return {"status": "ready" if ok else "not ready"}