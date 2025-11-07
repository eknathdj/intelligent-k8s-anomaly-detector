#!/usr/bin/env bash
set -euo pipefail

# Delete **all** created resources (interactive)
read -p "❗  Delete everything? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  make destroy-infrastructure
  k3d cluster delete k8s-anomaly || true
  docker system prune -af
  rm -rf .terraform terraform.tfstate* tfplan
  echo "🧹  Cleanup complete"
fi