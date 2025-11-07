from typing import List
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field

from api.core.container import Container
from anomaly_detector.metrics_processor import MetricsProcessor
from anomaly_detector.alert_generator import AlertGenerator

router = APIRouter(tags=["predictions"])

class MetricSample(BaseModel):
    metric: str
    value: float
    labels: dict = Field(default_factory=dict)

class PredictRequest(BaseModel):
    samples: List[MetricSample]

class PredictResponse(BaseModel):
    anomaly_score: float
    threshold_critical: float

# simple singleton container
container = Container()

@router.post("/predict", response_model=PredictResponse)
async def predict(body: PredictRequest):
    """
    Single-row prediction (real-time).
    Input: list of raw Prometheus samples → returns anomaly score.
    """
    if not container.detector:
        raise HTTPException(503, "Model not loaded")

    # convert to internal dict format
    raw = {s.metric: pd.DataFrame([{"value": s.value, **s.labels}]) for s in body.samples}
    features = container.processor.to_features(raw)
    if features.empty:
        raise HTTPException(422, "No valid features extracted")

    score = container.detector.predict(features).item()
    container.alerter.maybe_send([score], labels=body.samples[0].labels)

    return PredictResponse(
        anomaly_score=score,
        threshold_critical=container.alerter.threshold,
    )