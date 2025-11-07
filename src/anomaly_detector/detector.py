import joblib
import numpy as np
import pandas as pd
from pathlib import Path
from typing import Optional

from ml_pipeline.models import EnsembleModel   # installed via pip

class AnomalyDetector:
    """
    Thin wrapper that loads the **latest** ensemble model once at start-up
    and exposes a stateless `.predict()` method used by the FastAPI layer.
    """

    def __init__(self, model_dir: Path):
        self.model_dir = model_dir
        self.model: Optional[EnsembleModel] = None
        self._load()

    def _load(self):
        """Hot-reload latest model every N seconds (handled by caller)."""
        ensemble_path = self.model_dir / "ensemble.joblib"
        if not ensemble_path.exists():
            raise FileNotFoundError(f"Model not found: {ensemble_path}")
        self.model = joblib.load(ensemble_path)
        # scaler is bundled inside the ensemble

    def predict(self, features: pd.DataFrame) -> np.ndarray:
        """Return anomaly score ∈ [0, ∞) for each row."""
        if self.model is None:
            raise RuntimeError("Model not loaded")
        return self.model.predict(features)

    def health(self) -> bool:
        return self.model is not None