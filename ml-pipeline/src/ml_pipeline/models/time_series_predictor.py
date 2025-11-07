import numpy as np
import pandas as pd
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
from tensorflow.keras.optimizers import Adam
from sklearn.preprocessing import MinMaxScaler

class LSTMPredictor:
    """Predict next value(s); residual = |actual - predicted|."""

    def __init__(self, lookback: int = 60, horizon: int = 1, units: int = 50):
        self.lookback = lookback
        self.horizon = horizon
        self.units = units
        self.scaler = MinMaxScaler()
        self.model = None

    def _reshape(self, series: pd.Series) -> np.ndarray:
        scaled = self.scaler.fit_transform(series.values.reshape(-1, 1))
        X, y = [], []
        for i in range(self.lookback, len(scaled) - self.horizon + 1):
            X.append(scaled[i - self.lookback : i, 0])
            y.append(scaled[i : i + self.horizon, 0])
        return np.array(X), np.array(y)

    def fit(self, df: pd.DataFrame, target_col: str = "value"):
        series = df[target_col]
        X, y = self._reshape(series)
        X = X.reshape(X.shape[0], X.shape[1], 1)

        self.model = Sequential(
            [
                LSTM(self.units, return_sequences=False, input_shape=(self.lookback, 1)),
                Dense(self.horizon),
            ]
        )
        self.model.compile(optimizer=Adam(learning_rate=0.001), loss="mse")
        self.model.fit(X, y, epochs=10, batch_size=32, verbose=0)
        return self

    def predict(self, df: pd.DataFrame, target_col: str = "value") -> np.ndarray:
        series = df[target_col]
        scaled = self.scaler.transform(series.values.reshape(-1, 1))
        X = []
        for i in range(self.lookback, len(scaled) + 1):
            X.append(scaled[i - self.lookback : i, 0])
        X = np.array(X).reshape(len(X), self.lookback, 1)
        preds_scaled = self.model.predict(X, verbose=0)
        preds = self.scaler.inverse_transform(preds_scaled)
        return preds.flatten()

    def residual(self, df: pd.DataFrame, target_col: str = "value") -> np.ndarray:
        preds = self.predict(df, target_col)
        actual = df[target_col].iloc[self.lookback :].values
        return np.abs(actual - preds)