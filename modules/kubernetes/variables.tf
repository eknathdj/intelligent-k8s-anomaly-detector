# modules/kubernetes/variables.tf
# Variables for Kubernetes cluster module

# ===================================================================
# 🌍 GENERAL CONFIGURATION
# ===================================================================
variable "cloud_provider" {
  description = "Cloud provider (azure, aws, gcp)"
  type        = string
  
  validation {
    condition     = contains(["azure", "aws", "gcp"], var.cloud_provider)
    error_message = "Cloud provider must be one of: azure, aws, gcp."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Location/region for resources"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod", "local"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, local."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ===================================================================
# ☸️ CLUSTER CONFIGURATION
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
  
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format X.Y.Z (e.g., 1.28.3)"
  }
}

variable "default_node_pool_vm_size" {
  description = "VM size for default node pool"
  type        = string
  default     = "Standard_D4s_v3"
  
  validation {
    condition     = can(regex("^(Standard_|Basic_)[A-Z0-9]+s?_v[0-9]+$", var.default_node_pool_vm_size)) || 
                   can(regex("^[tm][0-9]\\.[a-z0-9]+$", var.default_node_pool_vm_size)) ||
                   var.cloud_provider != "azure"
    error_message = "Must be a valid VM size for the selected cloud provider."
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
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum node count for auto-scaling"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_node_count >= 0 && var.min_node_count <= var.max_node_count
    error_message = "Min node count must be between 0 and max_node_count."
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

# ===================================================================
# 🌐 NETWORKING CONFIGURATION
# ===================================================================
variable "vnet_id" {
  description = "Virtual network ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (for AWS multi-AZ)"
  type        = list(string)
  default     = []
}

variable "vnet_name" {
  description = "Virtual network name (for GCP)"
  type        = string
  default     = ""
}

variable "subnet_names" {
  description = "Map of subnet names by key (for GCP)"
  type        = map(string)
  default     = {}
}

variable "network_plugin" {
  description = "Network plugin (azure, kubenet, calico, cilium)"
  type        = string
  default     = "azure"
  
  validation {
    condition     = contains(["azure", "kubenet", "calico", "cilium"], var.network_plugin)
    error_message = "Network plugin must be one of: azure, kubenet, calico, cilium."
  }
}

variable "network_policy" {
  description = "Network policy (calico, azure, cilium)"
  type        = string
  default     = "calico"
  
  validation {
    condition     = contains(["calico", "azure", "cilium"], var.network_policy)
    error_message = "Network policy must be one of: calico, azure, cilium."
  }
}

variable "pod_cidr" {
  description = "CIDR range for pods"
  type        = string
  default     = "10.244.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.pod_cidr, 0))
    error_message = "Pod CIDR must be valid CIDR notation."
  }
}

variable "service_cidr" {
  description = "CIDR range for services"
  type        = string
  default     = "10.2.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "Service CIDR must be valid CIDR notation."
  }
}

variable "dns_service_ip" {
  description = "DNS service IP"
  type        = string
  default     = "10.2.0.10"
}

variable "docker_bridge_cidr" {
  description = "Docker bridge CIDR"
  type        = string
  default     = "172.17.0.1/16"
  
  validation {
    condition     = can(cidrhost(var.docker_bridge_cidr, 0))
    error_message = "Docker bridge CIDR must be valid CIDR notation."
  }
}

# ===================================================================
# 🔐 SECURITY CONFIGURATION
# ===================================================================
variable "enable_private_cluster" {
  description = "Enable private cluster (no public endpoint)"
  type        = bool
  default     = true
}

variable "enable_aad_rbac" {
  description = "Enable Azure AD RBAC"
  type        = bool
  default     = true
}

variable "aad_admin_group_ids" {
  description = "Azure AD admin group object IDs"
  type        = list(string)
  default     = []
}

variable "enable_network_policies" {
  description = "Enable Kubernetes network policies"
  type        = bool
  default     = true
}

variable "enable_pod_security_policy" {
  description = "Enable pod security policies"
  type        = bool
  default     = false  # Deprecated in newer K8s versions
}

variable "encryption_at_host_enabled" {
  description = "Enable encryption at host level"
  type        = bool
  default     = true
}

variable "disk_encryption_set_id" {
  description = "Disk encryption set ID for customer-managed keys"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for node access (AWS/GCP)"
  type        = string
  default     = ""
}

# ===================================================================
# 📊 MONITORING & LOGGING
# ===================================================================
variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID (Azure)"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable monitoring and logging"
  type        = bool
  default     = true
}

variable "monitoring_workspace_id" {
  description = "Monitoring workspace ID"
  type        = string
  default     = ""
}

# ===================================================================
# 🤖 ML PLATFORM CONFIGURATION
# ===================================================================
variable "enable_ml_gpu" {
  description = "Enable GPU support for ML workloads"
  type        = bool
  default     = false
}

variable "ml_node_pool_vm_size" {
  description = "VM size for ML node pool (GPU instances)"
  type        = string
  default     = "Standard_NC6s_v3"
}

variable "enable_ml_node_pool" {
  description = "Create separate ML node pool"
  type        = bool
  default     = true
}

# ===================================================================
# 🌍 AVAILABILITY & SCALING
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

variable "upgrade_channel" {
  description = "Cluster upgrade channel"
  type        = string
  default     = "regular"
  
  validation {
    condition     = contains(["rapid", "regular", "stable", "none"], var.upgrade_channel)
    error_message = "Upgrade channel must be one of: rapid, regular, stable, none."
  }
}

# ===================================================================
# 🏷️ TAGS & LABELS
# ===================================================================
variable "node_labels" {
  description = "Additional labels for all nodes"
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "Additional taints for all nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "system_node_pool_taints" {
  description = "Taints for system node pool"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "user_node_pool_taints" {
  description = "Taints for user node pool"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "ml_node_pool_taints" {
  description = "Taints for ML node pool"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = [
    {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NoSchedule"
    }
  ]
}

# ===================================================================
# 🔧 ADVANCED CONFIGURATION
# ===================================================================
variable "pod_security_standard" {
  description = "Pod security standard (baseline, restricted, privileged)"
  type        = string
  default     = "baseline"
  
  validation {
    condition     = contains(["baseline", "restricted", "privileged"], var.pod_security_standard)
    error_message = "Pod security standard must be one of: baseline, restricted, privileged."
  }
}

variable "enable_workload_identity" {
  description = "Enable workload identity (GCP)"
  type        = bool
  default     = true
}

variable "enable_pod_identity" {
  description = "Enable pod identity (Azure)"
  type        = bool
  default     = true
}

variable "enable_image_scanning" {
  description = "Enable container image scanning"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "Types of logs to collect"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  validation {
    condition     = alltrue([for log in var.cluster_log_types : contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log)])
    error_message = "Log types must be from: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "cluster_log_retention" {
  description = "Cluster log retention in days"
  type        = number
  default     = 30
  
  validation {
    condition     = var.cluster_log_retention >= 1 && var.cluster_log_retention <= 365
    error_message = "Log retention must be between 1 and 365 days."
  }
}

# ===================================================================
# 💰 COST OPTIMIZATION
# ===================================================================
variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Maximum price for spot instances"
  type        = string
  default     = "-1"  # -1 means on-demand price
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_profile" {
  description = "Cluster autoscaler configuration"
  type = object({
    balance_similar_node_groups      = bool
    max_graceful_termination_sec     = number
    scale_down_delay_after_add       = string
    scale_down_delay_after_delete    = string
    scale_down_delay_after_failure   = string
    scale_down_unneeded              = string
    scale_down_unready               = string
    scale_down_utilization_threshold = number
    scan_interval                    = string
    skip_nodes_with_local_storage    = bool
    skip_nodes_with_system_pods      = bool
  })
  default = {
    balance_similar_node_groups      = true
    max_graceful_termination_sec     = 600
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = 0.5
    scan_interval                    = "10s"
    skip_nodes_with_local_storage    = false
    skip_nodes_with_system_pods      = true
  }
}

# ===================================================================
# 🚨 EMERGENCY & RECOVERY
# ===================================================================
variable "enable_backup" {
  description = "Enable cluster backup"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 30
  
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 7 and 365 days."
  }
}

variable "enable_disaster_recovery" {
  description = "Enable disaster recovery features"
  type        = bool
  default     = false
}

variable "dr_region" {
  description = "Disaster recovery region"
  type        = string
  default     = ""
}