import json
import os
import requests
from typing import Dict

class AlertManagerClient:
    def __init__(self, base_url: str = None):
        self.base_url = (base_url or os.getenv("ALERTMANAGER_URL", "http://alertmanager:9093")).rstrip("/")

    def send(self, alert: Dict):
        resp = requests.post(
            f"{self.base_url}/api/v1/alerts",
            data=json.dumps([alert]),
            headers={"Content-Type": "application/json"},
            timeout=5,
        )
        resp.raise_for_status()