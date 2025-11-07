import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

class IsolationForestDetector:
    """Unsupervised point-anomaly detector."""

    def __init__(self, contamination: float = 0.01, n_estimators: int = 300, random_state=42):
        self.scaler = StandardScaler()
        self.model = IsolationForest(
            contamination=contamination,
            n_estimators=n_estimators,
            random_state=random_state,
            n_jobs=-1,
        )

    def fit(self, X: pd.DataFrame):
        X_scaled = self.scaler.fit_transform(X)
        self.model.fit(X_scaled)
        return self

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        """Return anomaly score (higher = more anomalous)."""
        X_scaled = self.scaler.transform(X)
        return self.model.decision_function(X_scaled) * -1

    def save(self, path: str):
        joblib.dump({"scaler": self.scaler, "model": self.model}, path)

    @classmethod
    def load(cls, path: str):
        bundle = joblib.load(path)
        inst = cls()
        inst.scaler = bundle["scaler"]
        inst.model = bundle["model"]
        return inst


class EnsembleModel:
    """Combine Isolation-Forest + LSTM residuals."""

    def __init__(self, iforest: IsolationForestDetector, lstm_predictor):
        self.iforest = iforest
        self.lstm = lstm_predictor

    def fit(self, X: pd.DataFrame):
        self.iforest.fit(X)
        self.lstm.fit(X)
        return self

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        iso_score = self.iforest.predict(X)
        lstm_residual = self.lstm.residual(X)
        # simple weighted sum (can be learnt later)
        return 0.6 * iso_score + 0.4 * lstm_residual