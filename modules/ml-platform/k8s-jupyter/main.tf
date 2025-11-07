locals {
  labels = merge(var.tags, {
    app       = "jupyter"
    component = "notebook"
  })
}

resource "kubernetes_deployment_v1" "jupyter" {
  metadata {
    name      = "${var.base_name}-jupyter"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.labels
    }
    template {
      metadata {
        labels = local.labels
      }
      spec {
        container {
          name  = "jupyter"
          image = "${var.image_repo}:${var.image_tag}"
          port {
            name           = "http"
            container_port = 8888
            protocol       = "TCP"
          }
          env {
            name  = "JUPYTER_ENABLE_LAB"
            value = "yes"
          }
          resources {
            limits   = var.resources.limits
            requests = var.resources.requests
          }
          volume_mount {
            name       = "data"
            mount_path = "/home/jovyan/work"
          }
        }
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.jupyter.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "jupyter" {
  metadata {
    name      = "${var.base_name}-jupyter-pvc"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_service_v1" "jupyter" {
  metadata {
    name      = "${var.base_name}-jupyter"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    type = "ClusterIP"
    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
    selector = local.labels
  }
}

resource "kubernetes_ingress_v1" "jupyter" {
  count = var.ingress_enabled ? 1 : 0
  metadata {
    name      = "${var.base_name}-jupyter"
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
              name = kubernetes_service_v1.jupyter.metadata[0].name
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
      secret_name = "${var.base_name}-jupyter-tls"
    }
  }
}