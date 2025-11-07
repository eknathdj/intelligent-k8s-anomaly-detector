# Architecture Overview

## System Context
```mermaid
graph TD
    User((User)) -->|Grafana| G[Grafana]
    SRE((SRE)) -->|ArgoCD| A[ArgoCD]
    A --> |Git| GH[GitHub]
    A --> |Helm| K8s[K8s API]
    K8s -->|Metrics| P[Prometheus]
    P -->|Query| ML[ML Pipeline]
    ML -->|Model| S[Model Registry]
    S -->|Serve| API[Anomaly API]
    API -->|Alert| AM[Alertmanager]