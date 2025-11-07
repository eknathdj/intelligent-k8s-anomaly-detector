
--------------------------------------------------
docs/deployment/troubleshooting.md
--------------------------------------------------
```markdown
# Troubleshooting

## Pod CrashLoopBackOff
1. `kubectl logs -n k8s-anomaly-dev deployment/anomaly-detector`
2. Check missing model: `ls /models/`
3. Re-run training: `make train`

## High False-Positive Rate
1. Lower contamination in `model_config.yaml`
2. Increase training window
3. Re-train: `make train`

## Prometheus OOM
1. Reduce retention: `helm upgrade kube-prom ... --set prometheus.prometheusSpec.retention=5d`
2. Add Thanos sidecar for long-term

## ArgoCD Sync Fails
1. `argocd app diff root-app`
2. Fix drift or hit `Sync` → `Replace`

Run-book links inside each alert annotation point here.