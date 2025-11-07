from prometheus_client import CollectorRegistry, Gauge, Counter, Histogram

registry = CollectorRegistry()

anomaly_score = Gauge(
    "anomaly_detector_score",
    "Latest anomaly score returned by model",
    labelnames=["pod", "namespace"],
    registry=registry,
)

inference_duration = Histogram(
    "anomaly_detector_inference_duration_seconds",
    "Model inference latency",
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0),
    registry=registry,
)

prediction_counter = Counter(
    "anomaly_detector_predictions_total",
    "Total number of prediction requests",
    labelnames=["status"],  # success / error
    registry=registry,
)