#!/usr/bin/env bash
set -euo pipefail

# Create CPU-burn pod → watch anomaly score in Grafana
NAMESPACE=${1:-k8s-anomaly-dev}
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cpu-spike-demo
  namespace: $NAMESPACE
spec:
  restartPolicy: Never
  containers:
  - name: burn
    image: alpine:latest
    command: ["sh", "-c", "while true; do :; done"]
    resources:
      requests:
        cpu: "100m"
      limits:
        cpu: "500m"
EOF

echo "🔥  CPU spike pod created"
kubectl wait --for=condition=Ready pod/cpu-spike-demo -n "$NAMESPACE"
echo "✅  Pod running – open Grafana dashboard"