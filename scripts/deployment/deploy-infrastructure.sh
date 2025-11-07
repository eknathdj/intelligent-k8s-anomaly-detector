#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./deploy-infrastructure.sh  azure  prod  eastus2
#   ./deploy-infrastructure.sh  local

CLOUD_PROVIDER=${1:-azure}
ENV=${2:-dev}
LOCATION=${3:-eastus}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
TF_DIR="$ROOT/infrastructure/terraform"

echo "🌍  Deploying infrastructure  $CLOUD_PROVIDER/$ENV/$LOCATION"

cd "$TF_DIR"

export TF_VAR_cloud_provider=$CLOUD_PROVIDER
export TF_VAR_environment=$ENV
export TF_VAR_location=$LOCATION

if [[ "$CLOUD_PROVIDER" == "local" ]]; then
  echo "🚀  Local mode → creating k3d cluster"
  make -C "$ROOT" k3d-up
  export TF_VAR_resource_group_name="k3d-local"
fi

terraform init -upgrade
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

echo "✅  Infrastructure deployed"