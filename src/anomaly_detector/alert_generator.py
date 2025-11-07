import os
from typing import List
from prometheus_client import AlertManagerClient   # optional thin wrapper

class AlertGenerator:
    """
    Send alerts to Alertmanager if score > threshold.
    In-cluster Alertmanager URL discovered via env.
    """

    def __init__(self, threshold_critical: float = 0.95):
        self.threshold = threshold_critical
        self.am_url = os.getenv("ALERTMANAGER_URL", "http://alertmanager.monitoring.svc:9093")

    def maybe_send(self, scores: List[float], labels: dict):
        for idx, score in enumerate(scores):
            if score > self.threshold:
                self._fire(
                    name="HighAnomalyScore",
                    labels={**labels, "pod_index": str(idx)},
                    annotations={
                        "summary": f"Anomaly score {score:.2f} exceeds threshold",
                        "runbook": "https://wiki.example.com/runbooks/high-anomaly",
                    },
                )

    def _fire(self, name: str, labels: dict, annotations: dict):
        # TODO: POST /api/v1/alerts  (json payload)
        # kept minimal to avoid external deps
        pass