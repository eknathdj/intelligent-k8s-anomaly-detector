"""Application configuration using Pydantic settings."""
import os
from typing import Optional
from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Application
    app_name: str = Field(default="k8s-anomaly-detector", env="APP_NAME")
    environment: str = Field(default="dev", env="ENVIRONMENT")
    debug: bool = Field(default=False, env="DEBUG")
    
    # API
    api_host: str = Field(default="0.0.0.0", env="API_HOST")
    api_port: int = Field(default=8080, env="API_PORT")
    api_workers: int = Field(default=2, env="API_WORKERS")
    
    # Logging
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    log_format: str = Field(default="json", env="LOG_FORMAT")
    
    # Model
    model_dir: str = Field(default="/models", env="MODEL_DIR")
    model_reload_interval: int = Field(default=300, env="MODEL_RELOAD_INTERVAL")
    
    # Prometheus
    prometheus_url: str = Field(
        default="http://prometheus.monitoring.svc:9090",
        env="PROMETHEUS_URL"
    )
    prometheus_query_timeout: int = Field(default=30, env="PROMETHEUS_QUERY_TIMEOUT")
    
    # Anomaly Detection
    anomaly_threshold_critical: float = Field(default=0.95, env="ANOMALY_THRESHOLD_CRITICAL")
    anomaly_threshold_warning: float = Field(default=0.80, env="ANOMALY_THRESHOLD_WARNING")
    
    # Alertmanager
    alertmanager_url: Optional[str] = Field(default=None, env="ALERTMANAGER_URL")
    
    # Kubernetes
    kubernetes_namespace: str = Field(default="default", env="KUBERNETES_NAMESPACE")
    in_cluster: bool = Field(default=True, env="IN_CLUSTER")
    
    class Config:
        """Pydantic config."""
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


# Global settings instance
settings = Settings()
