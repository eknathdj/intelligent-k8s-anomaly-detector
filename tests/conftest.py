"""Pytest configuration and fixtures."""
import os
import sys
import pytest
import numpy as np
import pandas as pd
from pathlib import Path
from fastapi.testclient import TestClient

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from api.main import app


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
def sample_metrics():
    """Sample metrics in API format."""
    return {
        "cpu_usage": [
            {"timestamp": 1640000000 + i * 60, "value": 45.2 + i * 0.5}
            for i in range(10)
        ],
        "memory_usage": [
            {"timestamp": 1640000000 + i * 60, "value": 1024 * (50 + i)}
            for i in range(10)
        ],
    }


@pytest.fixture
def sample_features():
    """Sample feature DataFrame."""
    return pd.DataFrame({
        "cpu_mean": [45.0],
        "cpu_std": [5.2],
        "cpu_min": [35.0],
        "cpu_max": [55.0],
        "memory_mean": [1024 * 50],
        "memory_std": [1024 * 5],
    })


@pytest.fixture
def mock_model(tmp_path):
    """Create a mock model file."""
    import joblib
    from sklearn.ensemble import IsolationForest
    
    # Create simple model
    model = IsolationForest(contamination=0.1, random_state=42)
    X = np.random.randn(100, 6)
    model.fit(X)
    
    # Save to temp directory
    model_path = tmp_path / "ensemble.joblib"
    joblib.dump(model, model_path)
    
    # Create version file
    version_path = tmp_path / "version.txt"
    version_path.write_text("test-v1.0")
    
    return tmp_path


@pytest.fixture
def prometheus_url():
    """Prometheus URL for testing."""
    return os.getenv("PROMETHEUS_URL", "http://localhost:9090")


@pytest.fixture(autouse=True)
def setup_env(monkeypatch, tmp_path):
    """Setup environment variables for tests."""
    monkeypatch.setenv("MODEL_DIR", str(tmp_path / "models"))
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("ENVIRONMENT", "test")
