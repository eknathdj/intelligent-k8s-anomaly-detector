locals {
  labels = merge(var.tags, {
    app       = "mlflow"
    component = "tracking"
  })
}

resource "kubernetes_deployment_v1" "mlflow" {
  metadata {
    name      = "${var.base_name}-mlflow"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = local.labels
    }
    template {
      metadata {
        labels = local.labels
      }
      spec {
        container {
          name  = "mlflow"
          image = "${var.image_repo}:${var.image_tag}"
          port {
            name           = "http"
            container_port = 5000
            protocol       = "TCP"
          }
          env_from {
            secret_ref { name = var.db_secret_name }
            secret_ref { name = var.artifacts_secret_name }
          }
          env {
            name  = "MLFLOW_ARTIFACT_ROOT"
            value = "$(ARTIFACT_ENDPOINT)/$(BUCKET)"  # populated from secret
          }
          resources {
            limits   = var.resources.limits
            requests = var.resources.requests
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "mlflow" {
  metadata {
    name      = "${var.base_name}-mlflow"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    type = var.service_type
    port {
      name        = "http"
      port        = 80
      target_port = "http"
      protocol    = "TCP"
    }
    selector = local.labels
  }
}

resource "kubernetes_ingress_v1" "mlflow" {
  count = var.ingress_enabled ? 1 : 0
  metadata {
    name      = "${var.base_name}-mlflow"
    namespace = var.namespace
    labels    = local.labels
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "cert-manager.io/cluster-issuer"             = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "true"
    }
  }
  spec {
    rule {
      host = var.ingress_fqdn
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.mlflow.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    tls {
      hosts       = [var.ingress_fqdn]
      secret_name = "${var.base_name}-mlflow-tls"
    }
  }
}