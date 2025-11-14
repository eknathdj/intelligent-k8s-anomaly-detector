"""Metrics endpoints for querying Prometheus."""
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta

from fastapi import APIRouter, HTTPException, Query, status

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/metrics")


@router.get("/query")
async def query_metrics(
    query: str = Query(..., description="PromQL query"),
    time: Optional[str] = Query(None, description="Evaluation timestamp (RFC3339 or Unix)"),
) -> Dict[str, Any]:
    """
    Query Prometheus metrics using PromQL.
    
    Args:
        query: PromQL query string
        time: Optional evaluation timestamp
        
    Returns:
        Dict: Query results
    """
    try:
        from utils.prometheus_client import PrometheusClient
        from api.core.config import settings
        
        logger.info(f"Metrics query: {query}")
        
        # Initialize Prometheus client
        client = PrometheusClient(base_url=settings.prometheus_url)
        
        # Execute query
        try:
            result = await client.query(query, time=time)
            return {
                "status": "success",
                "data": result
            }
        except Exception as e:
            logger.error(f"Prometheus query failed: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Prometheus query failed: {str(e)}"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Query error: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.get("/query_range")
async def query_range(
    query: str = Query(..., description="PromQL query"),
    start: str = Query(..., description="Start timestamp (RFC3339 or Unix)"),
    end: str = Query(..., description="End timestamp (RFC3339 or Unix)"),
    step: str = Query("15s", description="Query resolution step width"),
) -> Dict[str, Any]:
    """
    Query Prometheus metrics over a time range.
    
    Args:
        query: PromQL query string
        start: Start timestamp
        end: End timestamp
        step: Query resolution
        
    Returns:
        Dict: Query results
    """
    try:
        from utils.prometheus_client import PrometheusClient
        from api.core.config import settings
        
        logger.info(f"Range query: {query} from {start} to {end}")
        
        # Initialize Prometheus client
        client = PrometheusClient(base_url=settings.prometheus_url)
        
        # Execute range query
        try:
            result = await client.query_range(
                query=query,
                start=start,
                end=end,
                step=step
            )
            return {
                "status": "success",
                "data": result
            }
        except Exception as e:
            logger.error(f"Prometheus range query failed: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Prometheus query failed: {str(e)}"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Range query error: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.get("/default")
async def get_default_metrics() -> Dict[str, Any]:
    """
    Get default Kubernetes metrics for anomaly detection.
    
    Returns:
        Dict: Default metrics data
    """
    try:
        from utils.prometheus_client import PrometheusClient
        from api.core.config import settings
        
        logger.info("Fetching default metrics")
        
        # Initialize Prometheus client
        client = PrometheusClient(base_url=settings.prometheus_url)
        
        # Get default metrics (last 1 hour)
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=1)
        
        metrics = await client.get_default_metrics(
            start=start_time.isoformat(),
            end=end_time.isoformat()
        )
        
        return {
            "status": "success",
            "data": metrics,
            "time_range": {
                "start": start_time.isoformat(),
                "end": end_time.isoformat()
            }
        }
        
    except Exception as e:
        logger.error(f"Failed to fetch default metrics: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch metrics: {str(e)}"
        )
