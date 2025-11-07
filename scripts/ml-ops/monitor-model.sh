#!/usr/bin/env bash
set -euo pipefail

# Port-forward Grafana + open browser
echo "🎯  Opening Grafana dashboards..."
make port-forward-grafana &
sleep 3
open http://localhost:3000/d/anomaly-detection