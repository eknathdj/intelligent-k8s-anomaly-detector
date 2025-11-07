"""
Locust file:  pip install locust
locust -f tests/performance/load_test.py --host http://localhost:8080 -u 50 -r 10 -t 60s
"""
from locust import HttpUser, between, task

class AnomalyAPIUser(HttpUser):
    wait_time = between(0.5, 2)

    @task
    def predict(self):
        payload = {
            "samples": [
                {"metric": "cpu", "value": 0.9, "labels": {"pod": "load-test"}},
                {"metric": "memory", "value": 0.85, "labels": {"pod": "load-test"}},
            ]
        }
        with self.client.post("/api/v1/predict", json=payload, catch_response=True) as resp:
            if resp.status_code != 200:
                resp.failure("predict failed")
            elif resp.json()["anomaly_score"] > 1.0:
                resp.failure("score too high")