#!/usr/bin/env bash
set -euo pipefail

# Run pytest + coverage inside container
IMAGE="ghcr.io/eknathdj/ml-pipeline:0.1.0"

docker run --rm -it \
  -v "$(pwd)":/workspace \
  -w /workspace \
  "$IMAGE" \
  pytest --cov=ml_pipeline --cov-report=html:htmlcov tests/