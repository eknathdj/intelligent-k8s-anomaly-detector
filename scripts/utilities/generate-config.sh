#!/usr/bin/env bash
set -euo pipefail

# Generate local-env files from templates
ROOT="$(git rev-parse --show-toplevel)"
ENV=${1:-dev}

cp "$ROOT/.env.example" "$ROOT/.env"
cp "$ROOT/config/environments/${ENV}.yaml" "$ROOT/config/config.yaml"

echo "✅  Generated config for env=$ENV"