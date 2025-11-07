import time
import requests
from urllib.parse import urljoin

BASE = "http://localhost:8080"  # port-forward beforehand


def test_inference_happy_path():
    payload = {
        "samples": [
            {"metric": "cpu", "value": 0.8, "labels": {"pod": "test"}},
            {"metric": "memory", "value": 0.7, "labels": {"pod": "test"}},
        ]
    }
    resp = requests.post(urljoin(BASE, "/api/v1/predict"), json=payload, timeout=5)
    assert resp.status_code == 200
    data = resp.json()
    assert 0 <= data["anomaly_score"] <= 10  # arbitrary upper bound