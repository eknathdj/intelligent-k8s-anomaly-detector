from fastapi.testclient import TestClient


def test_liveness(client: TestClient):
    resp = client.get("/health/live")
    assert resp.status_code == 200
    assert resp.json() == {"status": "alive"}


def test_predict_empty(client: TestClient):
    resp = client.post("/api/v1/predict", json={"samples": []})
    assert resp.status_code == 422