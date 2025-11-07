from functools import lru_cache
from pydantic import BaseSettings, Field

class Settings(BaseSettings):
    app_name: str = "anomaly-detector"
    host: str = Field("0.0.0.0", env="HOST")
    port: int = Field(8080, env="PORT")
    workers: int = Field(2, env="WORKERS")
    model_dir: str = Field("/models", env="MODEL_DIR")
    reload_interval_seconds: int = Field(300, env="MODEL_RELOAD_INTERVAL")
    log_level: str = Field("INFO", env="LOG_LEVEL")
    prometheus_metrics_port: int = Field(8000, env="PROMETHEUS_METRICS_PORT")

    class Config:
        env_file = ".env"
        case_sensitive = False

@lru_cache
def get_settings() -> Settings:
    return Settings()

settings = get_settings()