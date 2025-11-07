import pandas as pd
import numpy as np
from typing import Dict, List, Tuple

class FeatureEngineer:
    """
    Stateless transforms that turn raw Prometheus tables into model-ready features.
    """

    @staticmethod
    def roll_stats(df: pd.DataFrame, window: str = "5m") -> pd.DataFrame:
        """Add rolling mean/std/min/max for each numeric column."""
        num = df.select_dtypes(include="number")
        rolled = (
            num.rolling(window, min_periods=1)
            .agg(["mean", "std", "min", "max"])
            .fillna(method="bfill")
        )
        rolled.columns = ["_".join(col) for col in rolled.columns]
        return pd.concat([df, rolled], axis=1)

    @staticmethod
    def lag_features(df: pd.DataFrame, lags: List[int] = None) -> pd.DataFrame:
        """Add lagged values (in minutes)."""
        lags = lags or [1, 2, 5, 10]
        for lag in lags:
            df[f"lag_{lag}m"] = df["value"].shift(lag)
        return df.fillna(method="bfill")

    @staticmethod
    def fft_energy(df: pd.DataFrame) -> pd.DataFrame:
        """Add top-3 FFT magnitude as anomaly proxy."""
        vals = df["value"].dropna().values
        if len(vals) < 10:
            df[["fft_1", "fft_2", "fft_3"]] = 0.0
            return df
        fft = np.fft.rfft(vals)
        mag = np.abs(fft)
        top3 = np.sort(mag)[-3:][::-1]
        for i, v in enumerate(top3, 1):
            df[f"fft_{i}"] = v
        return df

    def transform(self, raw: Dict[str, pd.DataFrame]) -> pd.DataFrame:
        """Return single feature matrix."""
        engineered = []
        for metric, df in raw.items():
            if df.empty:
                continue
            df = (
                df.rename(columns={"value": f"{metric}_raw"})
                .pipe(self.roll_stats)
                .pipe(self.lag_features)
                .pipe(self.fft_energy)
                .drop(columns=["__name__", "job", "instance"], errors="ignore")
            )
            engineered.append(df)
        if not engineered:
            return pd.DataFrame()
        # outer join on timestamp
        feat = engineered[0]
        for df in engineered[1:]:
            feat = feat.merge(df, on="timestamp", how="outer", suffixes=("", "_dup"))
        return feat.sort_values("timestamp").reset_index(drop=True)