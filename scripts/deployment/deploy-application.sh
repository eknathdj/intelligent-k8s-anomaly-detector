#!/usr/bin/env bash
set -euo pipefail

# Deploy (or upgrade) the Helm charts via ArgoCD app-of-apps
# Usage:  deploy-application.sh  dev

ENV=${1:-dev}
ROOT="$(git rev-parse --show-toplevel)"

echo "🚀  Deploying applications (ArgoCD) for env=$ENV"

kubectl apply -k "$ROOT/argocd/apps" \
  --context "$(kubectl config current-context)"

# wait for ArgoCD to sync
echo "⏳  Waiting for ArgoCD sync..."
kubectl wait --for=condition=Synced app/root-app --timeout=600s \
  -n argocd || true

echo "✅  Application set deployed"