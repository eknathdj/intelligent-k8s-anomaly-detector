from typing import Dict, Any
from kubernetes import client, config

def load_kube_config():
    try:
        config.load_incluster_config()  # inside pod
    except config.ConfigException:
        config.load_kube_config()       # local dev

def top_pods(namespace: str = "default", limit: int = 10) -> Dict[str, Any]:
    load_kube_config()
    v1 = client.CoreV1Api()
    metrics = client.CustomObjectsApi()
    pods = v1.list_namespaced_pod(namespace, limit=limit)
    # TODO: call metrics-server
    return {"pods": [p.metadata.name for p in pods.items]}