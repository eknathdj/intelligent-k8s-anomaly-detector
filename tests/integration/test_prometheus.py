import requests
import pytest

PROM = "http://kube-prom-prometheus.monitoring.svc:9090"


@pytest.mark.integration
def test_prometheus_ready():
    resp = requests.get(f"{PROM}/-/ready", timeout=10)
    assert resp.status_code == 200


@pytest.mark.integration
def test_anomaly_metric_exists():
    """Service must expose anomaly_score metric."""
    url = f"{PROM}/api/v1/query"
    params = {"query": "anomaly_score"}
    resp = requests.get(url, params=params, timeout=10)
    assert resp.status_code == 200
    assert len(resp.json()["data"]["result"]) > 0