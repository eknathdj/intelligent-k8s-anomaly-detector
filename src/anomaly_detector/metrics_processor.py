import logging
import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class MetricsProcessor:
    """
    Transform raw Prometheus metrics into feature matrix for ML model.
    
    Handles feature engineering including rolling statistics, lag features,
    and time-based features.
    """

    def __init__(self, window_size: int = 60):
        """
        Initialize the metrics processor.
        
        Args:
            window_size: Number of time points for rolling window calculations
        """
        try:
            self.window_size = window_size
            logger.info(f"MetricsProcessor initialized with window_size={window_size}")
            
            # Try to import feature engineer if available
            try:
                from ml_pipeline.data import FeatureEngineer
                self.engineer = FeatureEngineer()
                self.use_engineer = True
                logger.info("Using ml_pipeline FeatureEngineer")
            except ImportError:
                logger.warning("ml_pipeline not available, using built-in feature engineering")
                self.engineer = None
                self.use_engineer = False
                
        except Exception as e:
            logger.error(f"Failed to initialize MetricsProcessor: {e}", exc_info=True)
            raise

    def to_features(self, raw: Dict[str, Any]) -> pd.DataFrame:
        """
        Convert raw Prometheus metrics to feature DataFrame.
        
        Args:
            raw: Dictionary of metric name -> values/timestamps
            
        Returns:
            pd.DataFrame: Feature matrix ready for model prediction
            
        Raises:
            ValueError: If raw data is invalid or empty
        """
        try:
            if not raw:
                logger.warning("Empty raw metrics provided")
                raise ValueError("Raw metrics dictionary is empty")
            
            logger.debug(f"Processing metrics: {list(raw.keys())}")
            
            # Use ml_pipeline engineer if available
            if self.use_engineer and self.engineer is not None:
                try:
                    return self.engineer.transform(raw)
                except Exception as e:
                    logger.warning(f"FeatureEngineer failed, falling back to built-in: {e}")
            
            # Built-in feature engineering
            return self._builtin_transform(raw)
            
        except ValueError:
            raise
        except Exception as e:
            logger.error(f"Feature transformation failed: {e}", exc_info=True)
            raise ValueError(f"Failed to transform metrics: {e}") from e

    def _builtin_transform(self, raw: Dict[str, Any]) -> pd.DataFrame:
        """
        Built-in feature engineering when ml_pipeline is not available.
        
        Args:
            raw: Dictionary of metric name -> values
            
        Returns:
            pd.DataFrame: Engineered features
        """
        try:
            features = {}
            
            # Process each metric
            for metric_name, metric_data in raw.items():
                if isinstance(metric_data, dict):
                    values = metric_data.get('values', [])
                    timestamps = metric_data.get('timestamps', [])
                elif isinstance(metric_data, list):
                    values = metric_data
                    timestamps = list(range(len(values)))
                else:
                    logger.warning(f"Unexpected metric format for {metric_name}")
                    continue
                
                if not values:
                    logger.warning(f"No values for metric {metric_name}")
                    continue
                
                # Convert to numpy array
                values_array = np.array(values, dtype=float)
                
                # Basic statistics
                features[f"{metric_name}_mean"] = [np.mean(values_array)]
                features[f"{metric_name}_std"] = [np.std(values_array)]
                features[f"{metric_name}_min"] = [np.min(values_array)]
                features[f"{metric_name}_max"] = [np.max(values_array)]
                features[f"{metric_name}_median"] = [np.median(values_array)]
                
                # Current value (last in series)
                features[f"{metric_name}_current"] = [values_array[-1]]
                
                # Rate of change
                if len(values_array) > 1:
                    features[f"{metric_name}_rate"] = [values_array[-1] - values_array[-2]]
                else:
                    features[f"{metric_name}_rate"] = [0.0]
                
                # Percentiles
                features[f"{metric_name}_p95"] = [np.percentile(values_array, 95)]
                features[f"{metric_name}_p99"] = [np.percentile(values_array, 99)]
            
            # Create DataFrame
            df = pd.DataFrame(features)
            
            logger.debug(f"Generated {len(df.columns)} features from {len(raw)} metrics")
            
            return df
            
        except Exception as e:
            logger.error(f"Built-in transformation failed: {e}", exc_info=True)
            raise

    def validate_features(self, features: pd.DataFrame) -> bool:
        """
        Validate that features are in expected format.
        
        Args:
            features: Feature DataFrame to validate
            
        Returns:
            bool: True if valid, False otherwise
        """
        try:
            if features.empty:
                logger.warning("Feature DataFrame is empty")
                return False
            
            if features.isnull().any().any():
                logger.warning("Feature DataFrame contains null values")
                return False
            
            if not np.isfinite(features.values).all():
                logger.warning("Feature DataFrame contains infinite values")
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"Feature validation failed: {e}", exc_info=True)
            return False