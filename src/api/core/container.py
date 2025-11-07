from pathlib import Path
from typing import Optional
import asyncio
from prometheus_client import start_http_server

from api.core.config import settings
from anomaly_detector.detector import AnomalyDetector
from anomaly_detector.metrics_processor import MetricsProcessor
from anomaly_detector.alert_generator import AlertGenerator

class Container:
    def __init__(self):
        self.detector: Optional[AnomalyDetector] = None
        self.processor = MetricsProcessor()
        self.alerter = AlertGenerator()
        self._reload_task: Optional[asyncio.Task] = None

    async def start(self):
        # start Prometheus metrics sidecar
        start_http_server(settings.prometheus_metrics_port)
        # load model once
        self.detector = AnomalyDetector(Path(settings.model_dir))
        # schedule hot-reload
        self._reload_task = asyncio.create_task(self._periodic_reload())

    async def stop(self):
        if self._reload_task:
            self._reload_task.cancel()
            try:
                await self._reload_task
            except asyncio.CancelledError:
                pass

    async def _periodic_reload(self):
        while True:
            await asyncio.sleep(settings.reload_interval_seconds)
            self.detector._load()  # hot-swap model