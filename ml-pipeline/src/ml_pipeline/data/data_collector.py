import os
import datetime as dt
from typing import List, Dict, Any

import requests
import pandas as pd
import structlog

logger = structlog.get_logger(__name__)

class PrometheusCollector:
    """
    Thin wrapper around Prometheus HTTP API.
    Default query window: last 6 h, 1-min step.
    """

    def __init__(
        self,
        base_url: str = None,
        timeout: int = 30,
    ):
        self.base_url = (base_url or os.getenv("PROMETHEUS_URL", "http://prometheus:9090")).rstrip("/")
        self.timeout = timeout
        self.session = requests.Session()

    def query_range(
        self,
        query: str,
        start: dt.datetime = None,
        end: dt.datetime = None,
        step: str = "1m",
    ) -> pd.DataFrame:
        """Return pandas DataFrame with columns: timestamp, value, metric labels."""
        start = start or dt.datetime.utcnow() - dt.timedelta(hours=6)
        end = end or dt.datetime.utcnow()

        params = {
            "query": query,
            "start": start.timestamp(),
            "end": end.timestamp(),
            "step": step,
        }
        logger.info("Querying Prometheus", query=query, start=start, end=end, step=step)
        resp = self.session.get(
            f"{self.base_url}/api/v1/query_range",
            params=params,
            timeout=self.timeout,
        )
        resp.raise_for_status()
        raw = resp.json()["data"]["result"]

        frames = []
        for series in raw:
            df = (
                pd.DataFrame(series["values"], columns=["timestamp", "value"])
                .astype({"timestamp": int, "value": float})
                .assign(**series["metric"])
            )
            frames.append(df)
        if not frames:
            return pd.DataFrame(columns=["timestamp", "value"])
        return pd.concat(frames, ignore_index=True)

    def default_metrics(self) -> Dict[str, pd.DataFrame]:
        """Pull the minimal metric set we need for anomaly detection."""
        queries = {
            "cpu": 'rate(node_cpu_seconds_total{mode!="idle"}[5m])',
            "memory": '1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)',
            "disk": 'rate(node_disk_io_time_seconds_total[5m])',
            "network_rx": 'rate(node_network_receive_bytes_total[5m])',
            "network_tx": 'rate(node_network_transmit_bytes_total[5m])',
            "pod_cpu": 'rate(container_cpu_usage_seconds_total[5m])',
            "pod_memory": 'container_memory_working_set_bytes',
        }
        return {name: self.query_range(q) for name, q in queries.items()}