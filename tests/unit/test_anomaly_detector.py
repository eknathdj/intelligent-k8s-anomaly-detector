"""Unit tests for anomaly detector."""
import pytest
import numpy as np
import pandas as pd
from pathlib import Path


def test_detector_initialization(mock_model):
    """Test detector initialization."""
    from anomaly_detector.detector import AnomalyDetector
    
    detector = AnomalyDetector(model_dir=mock_model)
    assert detector.model is not None
    assert detector.health()


def test_detector_prediction(mock_model, sample_features):
    """Test detector prediction."""
    from anomaly_detector.detector import AnomalyDetector
    
    detector = AnomalyDetector(model_dir=mock_model)
    scores = detector.predict(sample_features)
    
    assert isinstance(scores, np.ndarray)
    assert len(scores) == len(sample_features)
    assert np.all(np.isfinite(scores))


def test_detector_no_model(tmp_path):
    """Test detector with missing model."""
    from anomaly_detector.detector import AnomalyDetector
    
    detector = AnomalyDetector(model_dir=tmp_path)
    assert not detector.health()


def test_detector_reload(mock_model):
    """Test model reload."""
    from anomaly_detector.detector import AnomalyDetector
    
    detector = AnomalyDetector(model_dir=mock_model)
    assert detector.reload()
    assert detector.health()


def test_detector_get_info(mock_model):
    """Test getting detector info."""
    from anomaly_detector.detector import AnomalyDetector
    
    detector = AnomalyDetector(model_dir=mock_model)
    info = detector.get_info()
    
    assert "model_loaded" in info
    assert "model_version" in info
    assert info["model_loaded"] is True
    assert info["model_version"] == "test-v1.0"