#!/usr/bin/env bash
set -euo pipefail

# Slowly allocate memory → trigger predictive alert
NAMESPACE=${1:-k8s-anomaly-dev}
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-leak-demo
  namespace: $NAMESPACE
spec:
  restartPolicy: Never
  containers:
  - name: leak
    image: python:3.11-slim
    command: ["python", "-c", "
import time, sys\n
buf = []\nwhile True:\n    buf.append(' ' * 10**6)\n    time.sleep(0.1)\n"]
    resources:
      requests:
        memory: "64Mi"
      limits:
        memory: "256Mi"
EOF

echo "💧  Memory-leak pod created"