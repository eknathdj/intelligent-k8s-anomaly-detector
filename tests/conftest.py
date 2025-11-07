import os
import pytest
from fastapi.testclient import TestClient
from src.api.main import app
from ml_pipeline.data import PrometheusCollector, FeatureEngineer
from ml_pipeline.models import IsolationForestDetector, LSTMPredictor

# allow tests to hit a real Prometheus (optional)
PROM_URL = os.getenv("PROMETHEUS_URL", "http://localhost:9090")


@pytest.fixture(scope="session")
def client():
    """FastAPI test client."""
    with TestClient(app) as c:
        yield c


@pytest.fixture
def sample_df():
    """Synthetic metric DataFrame."""
    ts = pd.date_range("2025-01-01", periods=200, freq="1min")
    df = pd.DataFrame(
        {
            "timestamp": ts.astype("int64") // 10**9,
            "value": np.sin(np.linspace(0, 20, 200)) + np.random.normal(0, 0.1, 200),
        }
    )
    return df


@pytest.fixture
def trained_ensemble(sample_df):
    """Pre-fitted ensemble model (small)."""
    feat = FeatureEngineer().transform({"cpu": sample_df})
    iso = IsolationForestDetector(contamination=0.02).fit(feat)
    lstm = LSTMPredictor(lookback=30).fit(feat)
    ensemble = EnsembleModel(iso, lstm)
    ensemble.fit(feat)
    return ensemble