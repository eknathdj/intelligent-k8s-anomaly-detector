#!/usr/bin/env bash
set -euo pipefail
# Apply everything in monitoring/ **before** Helm charts
echo "🎯  Applying static monitoring objects..."
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/alertmanager/
kubectl apply -f monitoring/grafana/
echo "✅  Static monitoring objects applied"