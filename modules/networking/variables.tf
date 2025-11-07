# ---------------------------------------------------------------------------
#  modules/networking/variables.tf
#  100 % compatible with the existing main.tf
# ---------------------------------------------------------------------------

# ------- Meta -------
variable "cloud_provider" {
  description = "Target cloud for this run. Must be azure, aws or gcp."
  type        = string
  validation {
    condition     = contains(["azure", "aws", "gcp"], var.cloud_provider)
    error_message = "Allowed values: azure, aws, gcp."
  }
}

variable "project_name" {
  description = "Short project name used in resource naming."
  type        = string
  default     = "k8s-anomaly"
}

variable "environment" {
  description = "Environment segment (dev, staging, prod...)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Primary region/zone for all networking resources."
  type        = string
}

variable "resource_group_name" {
  description = "Existing Azure resource group (required when cloud_provider=azure)."
  type        = string
  default     = ""
}

# ------- IP Topology -------
variable "vnet_address_space" {
  description = "CIDR block(s) for the whole VPC/VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  description = "Map of subnet definitions. Each value must contain address_prefixes (list) and optional cloud-specific keys."
  type = map(object({
    address_prefixes                    = list(string)
    availability_zone                   = optional(string)
    service_endpoints                   = optional(list(string), [])
    private_endpoint_network_policies_enabled = optional(bool, true)
    delegations                         = optional(list(string), [])
  }))
  default = {
    aks = {
      address_prefixes = ["10.0.1.0/24"]
    }
    monitoring = {
      address_prefixes = ["10.0.2.0/24"]
    }
    "ml-platform" = {
      address_prefixes = ["10.0.3.0/24"]
    }
  }
}

# GKE secondary ranges (used only when cloud_provider=gcp)
variable "pod_cidr" {
  description = "Secondary CIDR for GKE pods."
  type        = string
  default     = "10.48.0.0/14"
}

variable "service_cidr" {
  description = "Secondary CIDR for GKE services."
  type        = string
  default     = "10.52.0.0/20"
}

# ------- Features On/Off -------
variable "enable_ddos_protection" {
  description = "Create/attach a DDoS protection plan (Azure only, ignored on other clouds)."
  type        = bool
  default     = false
}

variable "enable_application_gateway" {
  description = "Deploy Azure Application Gateway (Azure only)."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC/VNet flow logs (supported on AWS & GCP; Azure ignored here)."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log-group retention (AWS only)."
  type        = number
  default     = 14
}

variable "enable_private_service_connect" {
  description = "Enable Google Private Service Connect (GCP only)."
  type        = bool
  default     = false
}

# ------- DNS / Domain -------
variable "dns_servers" {
  description = "Custom DNS servers for the VNet/VPC (empty list = cloud default)."
  type        = list(string)
  default     = []
}

# ------- Tagging -------
variable "tags" {
  description = "Base tags merged into every resource."
  type        = map(string)
  default = {
    Project   = "intelligent-k8s-anomaly-detector"
    ManagedBy = "Terraform"
  }
}

# ------- Advanced / Cloud-Agnostic Passthrough -------
variable "subnet_ids" {
  description = "Optional existing subnet map (keyed same as var.subnets) to skip creation. Used internally by App-GW logic."
  type        = map(string)
  default     = {}
}