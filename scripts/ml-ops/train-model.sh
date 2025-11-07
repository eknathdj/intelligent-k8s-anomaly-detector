#!/usr/bin/env bash
set -euo pipefail

# Local training inside container (same image as CronJob)
# Usage:  train-model.sh  --window 12  --tune

IMAGE="ghcr.io/eknathdj/ml-pipeline:0.1.0"
EXTRA_ARGS=("$@")

docker run --rm -it \
  -e PROMETHEUS_URL="http://host.docker.internal:9090" \
  -e MODEL_ARTIFACT_PATH="/tmp/models" \
  -v "$(pwd)/tmp/models":/tmp/models \
  "$IMAGE" \
  k8s-ml-train "${EXTRA_ARGS[@]}"