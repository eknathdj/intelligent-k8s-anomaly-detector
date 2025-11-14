import logging
import joblib
import numpy as np
import pandas as pd
from pathlib import Path
from typing import Optional, Union
from datetime import datetime

logger = logging.getLogger(__name__)


class AnomalyDetector:
    """
    Thin wrapper that loads the ensemble model and exposes a stateless
    `.predict()` method used by the FastAPI layer.
    
    Supports hot-reloading of models for zero-downtime updates.
    """

    def __init__(self, model_dir: Union[str, Path]):
        """
        Initialize the anomaly detector.
        
        Args:
            model_dir: Directory containing the model files
            
        Raises:
            ValueError: If model_dir is invalid
        """
        try:
            self.model_dir = Path(model_dir)
            if not self.model_dir.exists():
                logger.warning(f"Model directory does not exist: {self.model_dir}")
                self.model_dir.mkdir(parents=True, exist_ok=True)
                
            self.model: Optional[object] = None
            self.model_loaded_at: Optional[datetime] = None
            self.model_version: Optional[str] = None
            
            # Try to load model on initialization
            try:
                self._load()
            except Exception as e:
                logger.warning(f"Could not load model on init: {e}")
                
        except Exception as e:
            logger.error(f"Failed to initialize AnomalyDetector: {e}", exc_info=True)
            raise ValueError(f"Invalid model directory: {model_dir}") from e

    def _load(self) -> None:
        """
        Load the latest model from disk.
        
        Raises:
            FileNotFoundError: If model file doesn't exist
            Exception: If model loading fails
        """
        try:
            ensemble_path = self.model_dir / "ensemble.joblib"
            
            if not ensemble_path.exists():
                logger.error(f"Model file not found: {ensemble_path}")
                raise FileNotFoundError(f"Model not found: {ensemble_path}")
            
            logger.info(f"Loading model from {ensemble_path}")
            self.model = joblib.load(ensemble_path)
            self.model_loaded_at = datetime.utcnow()
            
            # Try to get model version if available
            version_path = self.model_dir / "version.txt"
            if version_path.exists():
                self.model_version = version_path.read_text().strip()
            else:
                self.model_version = "unknown"
                
            logger.info(
                f"Model loaded successfully. Version: {self.model_version}, "
                f"Loaded at: {self.model_loaded_at}"
            )
            
        except FileNotFoundError:
            raise
        except Exception as e:
            logger.error(f"Failed to load model: {e}", exc_info=True)
            raise Exception(f"Model loading failed: {e}") from e

    def reload(self) -> bool:
        """
        Reload the model from disk (hot-reload).
        
        Returns:
            bool: True if reload successful, False otherwise
        """
        try:
            logger.info("Attempting to reload model...")
            old_version = self.model_version
            self._load()
            logger.info(f"Model reloaded: {old_version} -> {self.model_version}")
            return True
        except Exception as e:
            logger.error(f"Failed to reload model: {e}", exc_info=True)
            return False

    def predict(self, features: pd.DataFrame) -> np.ndarray:
        """
        Return anomaly scores for input features.
        
        Args:
            features: DataFrame with feature columns
            
        Returns:
            np.ndarray: Anomaly scores ∈ [0, ∞) for each row
            
        Raises:
            RuntimeError: If model is not loaded
            ValueError: If features are invalid
        """
        try:
            if self.model is None:
                logger.error("Prediction attempted with no model loaded")
                raise RuntimeError("Model not loaded. Cannot make predictions.")
            
            if features.empty:
                logger.warning("Empty features provided for prediction")
                return np.array([])
            
            logger.debug(f"Predicting on {len(features)} samples")
            
            # Make prediction
            scores = self.model.predict(features)
            
            # Validate output
            if not isinstance(scores, np.ndarray):
                scores = np.array(scores)
                
            logger.debug(f"Prediction complete. Score range: [{scores.min():.3f}, {scores.max():.3f}]")
            
            return scores
            
        except RuntimeError:
            raise
        except Exception as e:
            logger.error(f"Prediction failed: {e}", exc_info=True)
            raise ValueError(f"Prediction error: {e}") from e

    def health(self) -> bool:
        """
        Check if detector is healthy (model loaded).
        
        Returns:
            bool: True if model is loaded and ready
        """
        is_healthy = self.model is not None
        if not is_healthy:
            logger.warning("Health check failed: model not loaded")
        return is_healthy
    
    def get_info(self) -> dict:
        """
        Get information about the loaded model.
        
        Returns:
            dict: Model information including version and load time
        """
        return {
            "model_loaded": self.model is not None,
            "model_version": self.model_version,
            "loaded_at": self.model_loaded_at.isoformat() if self.model_loaded_at else None,
            "model_dir": str(self.model_dir),
        }