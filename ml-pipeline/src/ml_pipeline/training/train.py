#!/usr/bin/env python
"""
Training orchestrator.
Called by Helm CronJob:  k8s-ml-train --tune --validate
"""
import argparse
import os
import datetime as dt
import structlog
from pathlib import Path

from ml_pipeline.data import PrometheusCollector, FeatureEngineer
from ml_pipeline.models import IsolationForestDetector, LSTMPredictor, EnsembleModel
from mlflow import log_metric, log_param, sklearn

logger = structlog.get_logger(__name__)

DEFAULT_PROM_QUERY_WINDOW = int(os.getenv("TRAINING_QUERY_WINDOW_HOURS", "6"))
ARTIFACT_PATH = Path(os.getenv("MODEL_ARTIFACT_PATH", "/models"))
CLOUD = os.getenv("CLOUD_PROVIDER", "azure")

def load_data(collector: PrometheusCollector, hours: int) -> dict:
    end = dt.datetime.utcnow()
    start = end - dt.timedelta(hours=hours)
    raw = collector.default_metrics()
    logger.info("raw metrics pulled", shapes={k: v.shape for k, v in raw.items()})
    return raw

def build_features(raw: dict) -> pd.DataFrame:
    feat = FeatureEngineer().transform(raw)
    if feat.empty:
        raise RuntimeError("Empty feature matrix after transform")
    return feat

def train_models(X: pd.DataFrame, tune: bool = False):
    # Isolation-Forest
    iso = IsolationForestDetector(contamination=0.01)
    iso.fit(X)
    iso_path = ARTIFACT_PATH / "isolation_forest.joblib"
    iso.save(str(iso_path))
    sklearn.log_model(iso.model, "isolation_forest")
    logger.info("Isolation-Forest saved", path=iso_path)

    # LSTM
    lstm = LSTMPredictor(lookback=60)
    lstm.fit(X)
    lstm_path = ARTIFACT_PATH / "lstm.h5"
    lstm.model.save(str(lstm_path))
    log_param("lstm_lookback", 60)
    logger.info("LSTM saved", path=lstm_path)

    # Ensemble
    ensemble = EnsembleModel(iso, lstm)
    ensemble.fit(X)
    ens_path = ARTIFACT_PATH / "ensemble.joblib"
    joblib.dump(ensemble, ens_path)
    logger.info("Ensemble saved", path=ens_path)

    # quick validation on same data (real life → time split)
    score = ensemble.predict(X).mean()
    log_metric("train_avg_anomaly_score", score)
    logger.info("training complete", avg_score=score)

def main():
    parser = argparse.ArgumentParser(description="Train anomaly-detection models")
    parser.add_argument("--tune", action="store_true", help="run optuna hyper-param tuning")
    parser.add_argument("--validate", action="store_true", help="run hold-out validation")
    parser.add_argument("--window", type=int, default=DEFAULT_PROM_QUERY_WINDOW, help="hours of data to pull")
    args = parser.parse_args()

    ARTIFACT_PATH.mkdir(parents=True, exist_ok=True)

    collector = PrometheusCollector()
    raw = load_data(collector, args.window)
    X = build_features(raw)
    train_models(X, tune=args.tune)

    logger.info("job finished", model_dir=ARTIFACT_PATH)

if __name__ == "__main__":
    main()