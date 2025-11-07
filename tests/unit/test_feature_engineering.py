import pandas as pd
from ml_pipeline.data import FeatureEngineer


def test_roll_stats_shape():
    df = pd.DataFrame({"value": range(100)})
    eng = FeatureEngineer()
    out = eng.roll_stats(df, window="10min")
    assert out.shape[1] == 5  # raw + mean + std + min + max
    assert not out.isna().any().any()