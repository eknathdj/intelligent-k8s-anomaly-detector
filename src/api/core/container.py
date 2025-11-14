"""Dependency injection container for application components."""
import logging
from typing import Optional
from pathlib import Path

from anomaly_detector.detector import AnomalyDetector
from anomaly_detector.metrics_processor import MetricsProcessor
from api.core.config import settings

logger = logging.getLogger(__name__)


class Container:
    """
    Dependency injection container managing application components.
    
    Handles initialization and lifecycle of:
    - Anomaly detector (ML model)
    - Metrics processor
    - External clients (Prometheus, Kubernetes)
    """
    
    def __init__(self):
        """Initialize the container."""
        self.detector: Optional[AnomalyDetector] = None
        self.metrics_processor: Optional[MetricsProcessor] = None
        self._started = False
        
    async def start(self) -> None:
        """
        Start the container and initialize all components.
        
        Raises:
            Exception: If initialization fails
        """
        if self._started:
            logger.warning("Container already started")
            return
        
        try:
            logger.info("Starting container...")
            
            # Initialize metrics processor
            logger.info("Initializing metrics processor...")
            self.metrics_processor = MetricsProcessor(window_size=60)
            logger.info("Metrics processor initialized")
            
            # Initialize anomaly detector
            logger.info(f"Initializing anomaly detector with model_dir={settings.model_dir}")
            try:
                self.detector = AnomalyDetector(model_dir=settings.model_dir)
                logger.info("Anomaly detector initialized")
            except Exception as e:
                logger.warning(f"Could not initialize detector: {e}. Will retry on first request.")
                # Create detector anyway, it will try to load model on first use
                self.detector = AnomalyDetector(model_dir=settings.model_dir)
            
            self._started = True
            logger.info("Container started successfully")
            
        except Exception as e:
            logger.error(f"Failed to start container: {e}", exc_info=True)
            raise
    
    async def stop(self) -> None:
        """
        Stop the container and cleanup resources.
        """
        if not self._started:
            logger.warning("Container not started")
            return
        
        try:
            logger.info("Stopping container...")
            
            # Cleanup resources if needed
            self.detector = None
            self.metrics_processor = None
            
            self._started = False
            logger.info("Container stopped successfully")
            
        except Exception as e:
            logger.error(f"Error stopping container: {e}", exc_info=True)
    
    def get_detector(self) -> AnomalyDetector:
        """
        Get the anomaly detector instance.
        
        Returns:
            AnomalyDetector: The detector instance
            
        Raises:
            RuntimeError: If container not started
        """
        if not self._started or self.detector is None:
            raise RuntimeError("Container not started or detector not initialized")
        return self.detector
    
    def get_metrics_processor(self) -> MetricsProcessor:
        """
        Get the metrics processor instance.
        
        Returns:
            MetricsProcessor: The processor instance
            
        Raises:
            RuntimeError: If container not started
        """
        if not self._started or self.metrics_processor is None:
            raise RuntimeError("Container not started or metrics processor not initialized")
        return self.metrics_processor


# Global container instance
_container: Optional[Container] = None


def get_container() -> Container:
    """
    Get the global container instance.
    
    Returns:
        Container: The global container
        
    Raises:
        RuntimeError: If container not initialized
    """
    global _container
    if _container is None:
        raise RuntimeError("Container not initialized")
    return _container


def set_container(container: Container) -> None:
    """Set the global container instance."""
    global _container
    _container = container
