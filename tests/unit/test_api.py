"""Unit tests for API endpoints."""
import pytest
from fastapi.testclient import TestClient


def test_root(client: TestClient):
    """Test root endpoint."""
    resp = client.get("/")
    assert resp.status_code == 200
    data = resp.json()
    assert "name" in data
    assert "version" in data


def test_liveness(client: TestClient):
    """Test liveness probe."""
    resp = client.get("/health/live")
    assert resp.status_code == 200
    assert resp.json() == {"status": "alive"}


def test_startup(client: TestClient):
    """Test startup probe."""
    resp = client.get("/health/startup")
    assert resp.status_code == 200
    assert resp.json() == {"status": "started"}


def test_predict_empty_metrics(client: TestClient):
    """Test prediction with empty metrics."""
    resp = client.post("/api/v1/predictions/predict", json={"metrics": {}})
    assert resp.status_code == 422


def test_predict_invalid_format(client: TestClient):
    """Test prediction with invalid format."""
    resp = client.post("/api/v1/predictions/predict", json={"invalid": "data"})
    assert resp.status_code == 422


def test_metrics_endpoint_exists(client: TestClient):
    """Test that metrics endpoint exists."""
    resp = client.get("/metrics")
    # Should return Prometheus metrics format
    assert resp.status_code == 200