#!/usr/bin/env bash
set -euo pipefail

# Trigger ML-training job and wait for completion
# Usage:  deploy-models.sh  staging

ENV=${1:-dev}
NAMESPACE="k8s-anomaly-${ENV}"

echo "🔬  Triggering model training  (env=$ENV)"

kubectl create job --from=cronjob/anomaly-detector-training \
  anomaly-detector-training-manual-$(date +%s) -n "$NAMESPACE"

echo "⏳  Waiting for job completion..."
kubectl wait --for=condition=complete job -l job-name=anomaly-detector-training \
  -n "$NAMESPACE" --timeout=900s

echo "✅  Models trained & pushed to MLflow"