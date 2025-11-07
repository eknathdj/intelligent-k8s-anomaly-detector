locals {
  base_name = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Module    = "ml-platform"
    Component = "mlflow"
  })
}

# =============================================================================
#  PostgreSQL  (cloud-native server)
# =============================================================================
module "db" {
  source = "./db"   # tiny sub-module per cloud (see next section)
  cloud_provider = var.cloud_provider
  project_name   = var.project_name
  environment    = var.environment
  location       = var.location
  resource_group_name = var.resource_group_name
  subnet_ids     = var.subnet_ids
  tags           = local.common_tags

  sku_name               = var.db_sku_name
  engine_version         = var.db_version
  storage_mb             = var.db_storage_mb
  backup_retention_days  = var.db_backup_retention_days
  admin_username         = var.db_admin_username
  ssl_enforcement_enabled= var.db_ssl_enforcement_enabled
  existing_password_secret = var.existing_db_password_secret
}

# =============================================================================
#  Object Storage  (artifacts)
# =============================================================================
module "artifacts" {
  source = "./artifacts"
  cloud_provider = var.cloud_provider
  project_name   = var.project_name
  environment    = var.environment
  location       = var.location
  resource_group_name = var.resource_group_name
  tags           = local.common_tags

  container_bucket = var.mlflow_artifact_container_bucket
  retention_days   = var.mlflow_artifact_retention_days
  existing_key_secret = var.existing_storage_account_key_secret
}

# =============================================================================
#  Kubernetes namespace & secrets
# =============================================================================
resource "kubernetes_namespace" "mlflow" {
  metadata {
    name = local.base_name
    labels = local.common_tags
  }
}

resource "kubernetes_secret" "db" {
  metadata {
    name      = "mlflow-db"
    namespace = kubernetes_namespace.mlflow.metadata[0].name
  }
  data = {
    username = base64encode(var.db_admin_username)
    password = base64encode(module.db.password)
    hostname = base64encode(module.db.fqdn)
    port     = base64encode("5432")
    database = base64encode("mlflow")
  }
  type = "Opaque"
}

resource "kubernetes_secret" "artifacts" {
  metadata {
    name      = "mlflow-artifacts"
    namespace = kubernetes_namespace.mlflow.metadata[0].name
  }
  data = {
    endpoint   = base64encode(module.artifacts.endpoint)
    access_key = base64encode(module.artifacts.access_key)
    secret_key = base64encode(module.artifacts.secret_key)
    bucket     = base64encode(module.artifacts.bucket)
  }
  type = "Opaque"
}

# =============================================================================
#  MLflow server (K8s deployment + service + ingress)
# =============================================================================
module "mlflow_server" {
  source = "./k8s-mlflow"
  namespace = kubernetes_namespace.mlflow.metadata[0].name
  base_name = local.base_name
  tags      = local.common_tags

  image_repo        = var.mlflow_image_repo
  image_tag         = var.mlflow_image_tag
  replicas          = var.mlflow_replicas
  resources         = var.mlflow_resources
  service_type      = var.mlflow_service_type
  ingress_enabled   = var.mlflow_ingress_enabled
  ingress_fqdn      = var.mlflow_ingress_fqdn
  db_secret_name    = kubernetes_secret.db.metadata[0].name
  artifacts_secret_name = kubernetes_secret.artifacts.metadata[0].name
}

# =============================================================================
#  Jupyter single-user (optional)
# =============================================================================
module "jupyter" {
  count = var.jupyter_enabled ? 1 : 0
  source = "./k8s-jupyter"
  namespace = kubernetes_namespace.mlflow.metadata[0].name
  base_name = local.base_name
  tags      = local.common_tags

  image_repo      = var.jupyter_image_repo
  image_tag       = var.jupyter_image_tag
  resources       = var.jupyter_resources
  ingress_enabled = var.jupyter_ingress_enabled
  ingress_fqdn    = var.jupyter_ingress_fqdn
}