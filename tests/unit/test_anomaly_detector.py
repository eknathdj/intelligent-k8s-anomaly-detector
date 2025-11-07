import numpy as np
from ml_pipeline.models import IsolationForestDetector


def test_isolation_forest_basic():
    rng = np.random.default_rng(42)
    normal = rng.normal(0, 1, (1000, 4))
    model = IsolationForestDetector(contamination=0.01)
    model.fit(normal)
    scores = model.predict(normal)
    assert scores.shape == (1000,)
    assert np.all(scores >= 0)  # non-negative after flip