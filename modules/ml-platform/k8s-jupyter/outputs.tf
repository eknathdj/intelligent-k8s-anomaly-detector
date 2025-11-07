output "service_name" {
  value = kubernetes_service_v1.jupyter.metadata[0].name
}