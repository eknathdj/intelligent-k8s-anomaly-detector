#!/usr/bin/env bash
set -euo pipefail

# Copy local model dir into cluster PVC (or upload to blob)
# Usage:  deploy-model.sh  /tmp/models  dev

MODEL_DIR=${1:-/tmp/models}
ENV=${2:-dev}
NAMESPACE="k8s-anomaly-${ENV}"

kubectl cp "$MODEL_DIR" \
  "$NAMESPACE/$(kubectl get pod -l app=anomaly-detector -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}'):/models/"
echo "✅  Model copied to cluster PVC"