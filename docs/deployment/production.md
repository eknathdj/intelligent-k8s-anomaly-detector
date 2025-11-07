
--------------------------------------------------
docs/deployment/production.md
--------------------------------------------------
```markdown
# Production Deployment

## Pre-flight Checklist
- [ ] DNS zones & TLS certs created
- [ ] Azure/AWS/GCP quotas checked (CPU, IPs, disks)
- [ ] Terraform remote state in Blob/S3 + locking
- [ ] secrets in Key-Vault/SSM/Secret-Manager
- [ ] Prometheus remote-write to long-term store
- [ ] Velero backup configured
- [ ] SOC-2 evidence collected (see compliance.md)

## Infrastructure
```bash
export ARM_USE_OIDC=true
make deploy-infra CLOUD=azure ENV=prod LOCATION=eastus2