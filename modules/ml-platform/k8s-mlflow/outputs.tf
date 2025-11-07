output "service_name" {
  value = kubernetes_service_v1.mlflow.metadata[0].name
}