# infrastructure/terraform/variables.tf
# Terraform variables for Intelligent Kubernetes Anomaly Detector

# ===================================================================
# 🌍 GENERAL CONFIGURATION
# ===================================================================
variable "cloud_provider" {
  description = "Cloud provider to deploy to (azure, aws, gcp)"
  type        = string
  default     = "azure"
  
  validation {
    condition     = contains(["azure", "aws", "gcp"], var.cloud_provider)
    error_message = "Cloud provider must be one of: azure, aws, gcp."
  }
}

variable "environment" {
  description = "Environment name (local, dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["local", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: local, dev, staging, prod."
  }
}

variable "location" {
  description = "Primary location/region for resources"
  type        = string
  default     = "East US"
}

variable "aws_region" {
  description = "AWS region (if different from location)"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region (if different from location)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aiops"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "it-infrastructure"
}

# ===================================================================
# ☸️ KUBERNETES CLUSTER CONFIGURATION
# ===================================================================
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "aiops-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.3"
}

variable "default_node_pool_vm_size" {
  description = "VM size for default node pool"
  type        = string
  default     = "Standard_D4s_v3"
  
  validation {
    condition     = can(regex("^Standard_[A-Z][0-9]+s_v[0-9]+$", var.default_node_pool_vm_size))
    error_message = "VM size must be a valid Azure VM size (e.g., Standard_D4s_v3)."
  }
}

variable "default_node_pool_count" {
  description = "Initial node count for default node pool"
  type        = number
  default     = 2
  
  validation {
    condition     = var.default_node_pool_count >= 1 && var.default_node_pool_count <= 100
    error_message = "Node count must be between 1 and 100."
  }
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pool"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum node count for auto-scaling"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_node_count >= 1 && var.min_node_count <= var.max_node_count
    error_message = "Min node count must be between 1 and max_node_count."
  }
}

variable "max_node_count" {
  description = "Maximum node count for auto-scaling"
  type        = number
  default     = 10
  
  validation {
    condition     = var.max_node_count >= var.min_node_count && var.max_node_count <= 100
    error_message = "Max node count must be between min_node_count and 100."
  }
}

variable "network_plugin" {
  description = "Network plugin for Kubernetes"
  type        = string
  default     = "azure"
  
  validation {
    condition     = contains(["azure", "kubenet", "calico", "cilium"], var.network_plugin)
    error_message = "Network plugin must be one of: azure, kubenet, calico, cilium."
  }
}

variable "network_policy" {
  description = "Network policy for Kubernetes"
  type        = string
  default     = "calico"
  
  validation {
    condition     = contains(["calico", "azure", "cilium"], var.network_policy)
    error_message = "Network policy must be one of: calico, azure, cilium."
  }
}

variable "enable_aad_rbac" {
  description = "Enable Azure AD RBAC for Kubernetes"
  type        = bool
  default     = true
}

variable "aad_admin_group_ids" {
  description = "Azure AD admin group object IDs"
  type        = list(string)
  default     = []
}

# ===================================================================
# 🌐 NETWORKING CONFIGURATION
# ===================================================================
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
  
  validation {
    condition     = can(cidrhost(var.vnet_address_space[0], 0))
    error_message = "vnet_address_space must be valid CIDR notation."
  }
}

variable "subnets" {
  description = "Subnet configuration"
  type = map(object({
    address_prefixes = list(string)
    service_endpoints = list(string)
    private_endpoint_network_policies_enabled = bool
    delegations = list(string)
  }))
  
  default = {
    aks = {
      address_prefixes = ["10.0.1.0/24"]
      service_endpoints = []
      private_endpoint_network_policies_enabled = false
      delegations = []
    }
    monitoring = {
      address_prefixes = ["10.0.2.0/24"]
      service_endpoints = []
      private_endpoint_network_policies_enabled = false
      delegations = []
    }
    ml_platform = {
      address_prefixes = ["10.0.3.0/24"]
      service_endpoints = []
      private_endpoint_network_policies_enabled = false
      delegations = []
    }
  }
}

# ===================================================================
# 📊 MONITORING & OBSERVABILITY
# ===================================================================
variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 15
  
  validation {
    condition     = var.prometheus_retention_days >= 1 && var.prometheus_retention_days <= 365
    error_message = "Retention must be between 1 and 365 days."
  }
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "100Gi"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_replicas" {
  description = "Number of Grafana replicas"
  type        = number
  default     = 2
  
  validation {
    condition     = var.grafana_replicas >= 1 && var.grafana_replicas <= 10
    error_message = "Grafana replicas must be between 1 and 10."
  }
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
  
  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 730
    error_message = "Log retention must be between 1 and 730 days."
  }
}

# ===================================================================
# 🤖 MACHINE LEARNING PLATFORM
# ===================================================================
variable "mlflow_tracking_uri" {
  description = "MLflow tracking URI"
  type        = string
  default     = "postgresql://mlflow:mlflow@postgres:5432/mlflow"
}

variable "mlflow_artifact_store" {
  description = "MLflow artifact store location"
  type        = string
  default     = "azure://mlflowartifacts"
}

variable "enable_ml_gpu" {
  description = "Enable GPU support for ML workloads"
  type        = bool
  default     = false
}

variable "ml_node_pool_vm_size" {
  description = "VM size for ML node pool"
  type        = string
  default     = "Standard_NC6s_v3"
}

# ===================================================================
# 🔐 SECURITY & COMPLIANCE
# ===================================================================
variable "enable_private_cluster" {
  description = "Enable private cluster (no public endpoint)"
  type        = bool
  default     = true
}

variable "enable_pod_security_policy" {
  description = "Enable pod security policies"
  type        = bool
  default     = true
}

variable "enable_network_policies" {
  description = "Enable Kubernetes network policies"
  type        = bool
  default     = true
}

variable "encryption_at_host_enabled" {
  description = "Enable encryption at host"
  type        = bool
  default     = true
}

variable "disk_encryption_set_id" {
  description = "Disk encryption set ID (for customer-managed keys)"
  type        = string
  default     = ""
}

# ===================================================================
# 🌍 CLOUD-SPECIFIC CONFIGURATION
# ===================================================================
variable "availability_zones" {
  description = "Availability zones for deployment"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "enable_zone_redundancy" {
  description = "Enable zone redundancy"
  type        = bool
  default     = true
}

# ===================================================================
# 🏷️ TAGS & LABELS
# ===================================================================
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ===================================================================
# 🔧 ADVANCED CONFIGURATION
# ===================================================================
variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "enable_ml_platform" {
  description = "Enable ML platform stack"
  type        = bool
  default     = true
}

variable "enable_automatic_upgrades" {
  description = "Enable automatic cluster upgrades"
  type        = bool
  default     = false
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day_of_week = string
    start_time  = string
    duration    = number
  })
  default = {
    day_of_week = "Sunday"
    start_time  = "02:00"
    duration    = 4
  }
}