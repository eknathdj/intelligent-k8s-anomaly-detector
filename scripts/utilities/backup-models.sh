#!/usr/bin/env bash
set -euo pipefail

# Backup MLflow models to timestamped tar
BUCKET=${1:-mlflow-artifacts}
DATE=$(date +%F-%H-%M)

az storage blob upload-batch \
  --source /models \
  --destination "$BUCKET/backups/$DATE" \
  --account-name "$AZURE_STORAGE_ACCOUNT"

echo "✅  Models backed up to $BUCKET/backups/$DATE"