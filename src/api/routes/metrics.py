from fastapi import APIRouter
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

router = APIRouter(tags=["metrics"])

@router.get("/metrics", response_class=PlainTextResponse)
async def metrics():
    """
    Expose Prometheus metrics for this service
    (already mounted at /metrics in main.py; duplicated for clarity).
    """
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)