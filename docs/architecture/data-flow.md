
--------------------------------------------------
docs/architecture/data-flow.md
--------------------------------------------------
```mermaid
sequenceDiagram
    participant K8s
    participant Prometheus
    participant CronJob
    participant MLflow
    participant API
    participant Grafana
    participant Alertmanager

    K8s->>Prometheus: expose /metrics
    loop every 6 h
        CronJob->>Prometheus: query_range()
        CronJob->>CronJob: feature engineering
        CronJob->>MLflow: log_model()
    end
    API->>MLflow: download latest
    K8s->>API: POST /predict
    API->>API: ensemble.predict()
    alt score > 0.95
        API->>Alertmanager: alert
    end
    Prometheus->>Grafana: datasource