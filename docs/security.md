
--------------------------------------------------
docs/security.md  (lightweight)
--------------------------------------------------
```markdown
# Security

## RBAC
* Least-privilege ServiceAccounts per component
* PodSecurityStandard=restricted enforced on anomaly-detector NS
* Terraform uses Workload Identity (GCP) / OIDC (Azure) / IRSA (AWS)

## Secrets
* DB creds, storage keys → cloud Key-Vault
* Sealed-Secrets for Git-stored manifests (optional)
* External-Secrets-Operator for runtime sync

## Network
* NSGs / firewall rules in Terraform modules
* mTLS between Prometheus & Alertmanager (optional)
* Private Link for PostgreSQL / Blob / S3

## Compliance
* CIS 1.8 benchmark applied via kube-bench DaemonSet
* GDPR: data retention 30 d, right-to-be-forgotten API
* SOC-2: evidence collected in `docs/compliance/`