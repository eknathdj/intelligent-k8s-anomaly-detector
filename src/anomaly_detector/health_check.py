from prometheus_client import Gauge, Info
from anomaly_detector.detector import AnomalyDetector

# Prometheus metrics for **this** service
health_metric = Gauge("anomaly_detector_health", "1 = healthy")
model_info = Info("anomaly_detector_model", "Model metadata")
ready = False


def check_health(detector: AnomalyDetector) -> bool:
    global ready
    ok = detector.health()
    health_metric.set(1 if ok else 0)
    if ok:
        model_info.info({"version": "0.1.0", "type": "ensemble"})
        ready = True
    return ok