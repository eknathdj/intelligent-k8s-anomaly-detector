variable "cloud_provider" {
  description = "Target cloud: azure, aws or gcp."
  type        = string
  validation {
    condition     = contains(["azure", "aws", "gcp"], var.cloud_provider)
    error_message = "Allowed values: azure, aws, gcp."
  }
}

variable "project_name" {
  description = "Short name for resource naming."
  type        = string
  default     = "k8s-anomaly"
}

variable "environment" {
  description = "Environment segment (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Region/zone for all resources."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group (required when cloud_provider=azure)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Base tags merged into every resource."
  type        = map(string)
  default = {
    Project   = "intelligent-k8s-anomaly-detector"
    ManagedBy = "Terraform"
  }
}

# ------- Networking -------
variable "subnet_ids" {
  description = "Map of subnet keys to subnet IDs (output from networking module)."
  type        = map(string)
}

variable "private_dns_zone_id" {
  description = "Optional private DNS zone ID (Azure) or internal domain (GCP/AWS)."
  type        = string
  default     = ""
}

# ------- Storage -------
variable "mlflow_artifact_storage_type" {
  description = "Where MLflow artifacts live: blob (Azure), s3 (AWS), gcs (GCP)."
  type        = string
  default     = "blob"
  validation {
    condition     = contains(["blob", "s3", "gcs"], var.mlflow_artifact_storage_type)
    error_message = "Allowed: blob, s3, gcs."
  }
}

variable "mlflow_artifact_container_bucket" {
  description = "Name of the container/bucket for MLflow artifacts (created if not exists)."
  type        = string
  default     = "mlflow-artifacts"
}

variable "mlflow_artifact_retention_days" {
  description = "Lifecycle retention in days (0 = keep forever)."
  type        = number
  default     = 0
}

# ------- Database -------
variable "db_sku_name" {
  description = "Cloud-specific SKU/size string for PostgreSQL."
  type        = string
  default = {
    azure = "GP_Standard_D2s_v3"
    aws   = "db.t3.micro"
    gcp   = "db-custom-2-3840"
  }[var.cloud_provider]
}

variable "db_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "15"
}

variable "db_storage_mb" {
  description = "Storage size in MB."
  type        = number
  default     = 10240   # 10 GiB
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "db_admin_username" {
  type    = string
  default = "mlflow"
}

variable "db_ssl_enforcement_enabled" {
  type    = bool
  default = true
}

# ------- MLflow Server -------
variable "mlflow_replicas" {
  type    = number
  default = 2
}

variable "mlflow_image_repo" {
  type    = string
  default = "ghcr.io/eknathdj/mlflow-server"
}

variable "mlflow_image_tag" {
  type    = string
  default = "v0.1.0"
}

variable "mlflow_resources" {
  description = "K8s resources block for MLflow container."
  type = object({
    limits   = map(string)
    requests = map(string)
  })
  default = {
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
    requests = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }
}

variable "mlflow_service_type" {
  type    = string
  default = "ClusterIP"
}

variable "mlflow_ingress_enabled" {
  type    = bool
  default = false
}

variable "mlflow_ingress_fqdn" {
  type    = string
  default = "mlflow.example.com"
}

# ------- Jupyter/JupyterHub -------
variable "jupyter_enabled" {
  description = "Deploy single-user Jupyter instance (set false to use external Hub)."
  type        = bool
  default     = true
}

variable "jupyter_image_repo" {
  type    = string
  default = "ghcr.io/eknathdj/jupyter-ml"
}

variable "jupyter_image_tag" {
  type    = string
  default = "v0.1.0"
}

variable "jupyter_resources" {
  type = object({
    limits   = map(string)
    requests = map(string)
  })
  default = {
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
}

variable "jupyter_ingress_enabled" {
  type    = bool
  default = false
}

variable "jupyter_ingress_fqdn" {
  type    = string
  default = "jupyter.example.com"
}

# ------- Secrets -------
variable "existing_db_password_secret" {
  description = "K8s secret name that already contains key 'password'.  If empty a random one is created."
  type        = string
  default     = ""
}

variable "existing_storage_account_key_secret" {
  description = "K8s secret name that already contains key 'account-key'.  If empty a random one is created (Azure only)."
  type        = string
  default     = ""
}