"""Prediction endpoints for anomaly detection."""
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/predictions")


class MetricSample(BaseModel):
    """A single metric sample."""
    timestamp: int = Field(..., description="Unix timestamp")
    value: float = Field(..., description="Metric value")


class PredictionRequest(BaseModel):
    """Request body for anomaly prediction."""
    metrics: Dict[str, List[MetricSample]] = Field(
        ...,
        description="Dictionary of metric_name -> list of samples",
        example={
            "cpu_usage": [
                {"timestamp": 1640000000, "value": 45.2},
                {"timestamp": 1640000060, "value": 48.1},
            ]
        }
    )
    threshold: Optional[float] = Field(
        None,
        description="Custom anomaly threshold (0-1)",
        ge=0.0,
        le=1.0
    )


class PredictionResponse(BaseModel):
    """Response body for anomaly prediction."""
    anomaly_score: float = Field(..., description="Anomaly score (0-1)")
    is_anomaly: bool = Field(..., description="Whether an anomaly was detected")
    threshold: float = Field(..., description="Threshold used for detection")
    timestamp: str = Field(..., description="Prediction timestamp")
    model_version: Optional[str] = Field(None, description="Model version used")


@router.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest) -> PredictionResponse:
    """
    Predict anomaly score for given metrics.
    
    Args:
        request: Prediction request with metrics data
        
    Returns:
        PredictionResponse: Anomaly prediction result
        
    Raises:
        HTTPException: If prediction fails
    """
    try:
        from api.core.container import get_container
        from api.core.config import settings
        
        logger.info(f"Received prediction request with {len(request.metrics)} metrics")
        
        # Get container components
        try:
            container = get_container()
            detector = container.get_detector()
            processor = container.get_metrics_processor()
        except RuntimeError as e:
            logger.error(f"Container not ready: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Service not ready. Please try again later."
            )
        
        # Validate request
        if not request.metrics:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No metrics provided"
            )
        
        # Convert request to raw metrics format
        raw_metrics = {}
        for metric_name, samples in request.metrics.items():
            if not samples:
                continue
            raw_metrics[metric_name] = {
                "timestamps": [s.timestamp for s in samples],
                "values": [s.value for s in samples]
            }
        
        # Process metrics into features
        try:
            features = processor.to_features(raw_metrics)
            logger.debug(f"Generated {len(features.columns)} features")
        except Exception as e:
            logger.error(f"Feature processing failed: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Failed to process metrics: {str(e)}"
            )
        
        # Make prediction
        try:
            scores = detector.predict(features)
            anomaly_score = float(scores[0]) if len(scores) > 0 else 0.0
            
            # Normalize score to 0-1 range if needed
            if anomaly_score > 1.0:
                anomaly_score = min(anomaly_score / 100.0, 1.0)
            
        except Exception as e:
            logger.error(f"Prediction failed: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Prediction failed: {str(e)}"
            )
        
        # Determine threshold
        threshold = request.threshold or settings.anomaly_threshold_warning
        is_anomaly = anomaly_score >= threshold
        
        # Get model info
        model_info = detector.get_info()
        
        logger.info(
            f"Prediction complete: score={anomaly_score:.3f}, "
            f"is_anomaly={is_anomaly}, threshold={threshold}"
        )
        
        return PredictionResponse(
            anomaly_score=anomaly_score,
            is_anomaly=is_anomaly,
            threshold=threshold,
            timestamp=datetime.utcnow().isoformat(),
            model_version=model_info.get("model_version")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in prediction: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.get("/model/info")
async def model_info() -> Dict[str, Any]:
    """
    Get information about the loaded model.
    
    Returns:
        Dict: Model information
    """
    try:
        from api.core.container import get_container
        
        container = get_container()
        detector = container.get_detector()
        
        return detector.get_info()
        
    except RuntimeError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service not ready"
        )
    except Exception as e:
        logger.error(f"Failed to get model info: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve model information"
        )


@router.post("/model/reload")
async def reload_model() -> Dict[str, Any]:
    """
    Reload the ML model from disk.
    
    Returns:
        Dict: Reload status
    """
    try:
        from api.core.container import get_container
        
        logger.info("Model reload requested")
        
        container = get_container()
        detector = container.get_detector()
        
        success = detector.reload()
        
        if success:
            logger.info("Model reloaded successfully")
            return {
                "status": "success",
                "message": "Model reloaded successfully",
                "model_info": detector.get_info()
            }
        else:
            logger.error("Model reload failed")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Model reload failed"
            )
            
    except RuntimeError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service not ready"
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Model reload error: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Model reload failed: {str(e)}"
        )
