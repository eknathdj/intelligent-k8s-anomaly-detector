"""Prometheus client for querying metrics."""
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime

import httpx

logger = logging.getLogger(__name__)


class PrometheusClient:
    """Client for querying Prometheus metrics."""
    
    def __init__(self, base_url: str, timeout: int = 30):
        """
        Initialize Prometheus client.
        
        Args:
            base_url: Prometheus server URL
            timeout: Request timeout in seconds
        """
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        logger.info(f"PrometheusClient initialized: {self.base_url}")
    
    async def query(self, query: str, time: Optional[str] = None) -> Dict[str, Any]:
        """
        Execute instant query.
        
        Args:
            query: PromQL query
            time: Optional evaluation timestamp
            
        Returns:
            Dict: Query result
        """
        try:
            params = {"query": query}
            if time:
                params["time"] = time
            
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(
                    f"{self.base_url}/api/v1/query",
                    params=params
                )
                response.raise_for_status()
                
                data = response.json()
                if data.get("status") != "success":
                    raise Exception(f"Query failed: {data.get('error')}")
                
                return data.get("data", {})
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error querying Prometheus: {e}")
            raise
        except Exception as e:
            logger.error(f"Error querying Prometheus: {e}", exc_info=True)
            raise
    
    async def query_range(
        self,
        query: str,
        start: str,
        end: str,
        step: str = "15s"
    ) -> Dict[str, Any]:
        """
        Execute range query.
        
        Args:
            query: PromQL query
            start: Start timestamp
            end: End timestamp
            step: Query resolution
            
        Returns:
            Dict: Query result
        """
        try:
            params = {
                "query": query,
                "start": start,
                "end": end,
                "step": step
            }
            
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(
                    f"{self.base_url}/api/v1/query_range",
                    params=params
                )
                response.raise_for_status()
                
                data = response.json()
                if data.get("status") != "success":
                    raise Exception(f"Query failed: {data.get('error')}")
                
                return data.get("data", {})
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error querying Prometheus range: {e}")
            raise
        except Exception as e:
            logger.error(f"Error querying Prometheus range: {e}", exc_info=True)
            raise
    
    async def get_default_metrics(
        self,
        start: str,
        end: str,
        namespace: str = "default"
    ) -> Dict[str, Any]:
        """
        Get default Kubernetes metrics for anomaly detection.
        
        Args:
            start: Start timestamp
            end: End timestamp
            namespace: Kubernetes namespace
            
        Returns:
            Dict: Metrics data
        """
        try:
            metrics = {}
            
            # CPU usage
            cpu_query = f'rate(container_cpu_usage_seconds_total{{namespace="{namespace}"}}[5m])'
            metrics["cpu_usage"] = await self.query_range(cpu_query, start, end)
            
            # Memory usage
            memory_query = f'container_memory_usage_bytes{{namespace="{namespace}"}}'
            metrics["memory_usage"] = await self.query_range(memory_query, start, end)
            
            # Network I/O
            network_rx_query = f'rate(container_network_receive_bytes_total{{namespace="{namespace}"}}[5m])'
            metrics["network_rx"] = await self.query_range(network_rx_query, start, end)
            
            network_tx_query = f'rate(container_network_transmit_bytes_total{{namespace="{namespace}"}}[5m])'
            metrics["network_tx"] = await self.query_range(network_tx_query, start, end)
            
            # Disk I/O
            disk_read_query = f'rate(container_fs_reads_bytes_total{{namespace="{namespace}"}}[5m])'
            metrics["disk_read"] = await self.query_range(disk_read_query, start, end)
            
            disk_write_query = f'rate(container_fs_writes_bytes_total{{namespace="{namespace}"}}[5m])'
            metrics["disk_write"] = await self.query_range(disk_write_query, start, end)
            
            logger.info(f"Fetched {len(metrics)} default metrics")
            return metrics
            
        except Exception as e:
            logger.error(f"Error fetching default metrics: {e}", exc_info=True)
            raise
