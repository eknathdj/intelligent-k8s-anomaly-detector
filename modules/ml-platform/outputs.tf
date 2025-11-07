output "namespace" {
  value = kubernetes_namespace.mlflow.metadata[0].name
}

output "db_fqdn" {
  value = module.db.fqdn
}

output "db_port" {
  value = 5432
}

output "artifact_bucket" {
  value = module.artifacts.bucket
}

output "artifact_endpoint" {
  value = module.artifacts.endpoint
}

output "mlflow_service_name" {
  value = module.mlflow_server.service_name
}

output "mlflow_internal_url" {
  value = "http://${module.mlflow_server.service_name}.${kubernetes_namespace.mlflow.metadata[0].name}.svc.cluster.local:5000"
}

output "mlflow_external_fqdn" {
  value = var.mlflow_ingress_enabled ? var.mlflow_ingress_fqdn : ""
}

output "jupyter_external_fqdn" {
  value = var.jupyter_enabled && var.jupyter_ingress_enabled ? var.jupyter_ingress_fqdn : ""
}

output "secrets" {
  value = {
    db        = kubernetes_secret.db.metadata[0].name
    artifacts = kubernetes_secret.artifacts.metadata[0].name
  }
}