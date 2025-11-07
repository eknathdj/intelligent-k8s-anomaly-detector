import pandas as pd
from ml_pipeline.data import FeatureEngineer   # reuse same logic

class MetricsProcessor:
    """
    Turn raw Prometheus samples (dict) into the **exact** feature matrix
    the model was trained on.
    """

    def __init__(self):
        self.engineer = FeatureEngineer()

    def to_features(self, raw: dict) -> pd.DataFrame:
        """
        raw: dict returned by PrometheusCollector.default_metrics()
        returns: pd.DataFrame (n_rows, n_features)
        """
        return self.engineer.transform(raw)