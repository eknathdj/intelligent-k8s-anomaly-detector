# infrastructure/terraform/main.tf
# Main Terraform configuration for Intelligent Kubernetes Anomaly Detector

# ===================================================================
# 🌍 PROVIDERS & DATA SOURCES
# ===================================================================
terraform {
  required_version = ">= 1.9.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
  # Backend configuration will be provided at runtime
  backend "azurerm" {}
}

# Data source for current Azure subscription
data "azurerm_client_config" "current" {}

# Data source for AWS caller identity (when using AWS)
data "aws_caller_identity" "current" {}

# Data source for Google Cloud project (when using GCP)
data "google_project" "current" {}

# ===================================================================
# 📊 LOCAL VALUES & RANDOM RESOURCES
# ===================================================================
locals {
  # Common tags applied to all resources
  common_tags = {
    Environment     = var.environment
    Project         = var.project_name
    ManagedBy       = "Terraform"
    CreatedBy       = "AI/ML Anomaly Detector"
    CostCenter      = var.cost_center
    Repository      = "https://github.com/your-username/intelligent-k8s-anomaly-detector"
    TerraformState  = "${var.environment}.terraform.tfstate"
  }
  
  # Resource naming conventions
  resource_prefix = "${var.project_name}-${var.environment}"
  
  # Cloud-specific configurations
  cloud_config = {
    azure = {
      enabled = var.cloud_provider == "azure"
      region  = var.location
    }
    aws = {
      enabled = var.cloud_provider == "aws"
      region  = var.aws_region != "" ? var.aws_region : var.location
    }
    gcp = {
      enabled = var.cloud_provider == "gcp"
      region  = var.gcp_region != "" ? var.gcp_region : var.location
    }
  }
}

# Random pet for unique resource naming
resource "random_pet" "main" {
  length    = 2
  separator = "-"
}

# Random string for unique identifiers
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# ===================================================================
# 📁 RESOURCE GROUP / PROJECT SETUP
# ===================================================================

# Azure Resource Group
resource "azurerm_resource_group" "main" {
  count    = local.cloud_config.azure.enabled ? 1 : 0
  name     = "${local.resource_prefix}-${random_pet.main.id}"
  location = var.location
  tags     = local.common_tags
}

# AWS Resource Group (using tags instead of resource groups)
locals {
  aws_resource_tags = merge(local.common_tags, {
    ResourceGroup = "${local.resource_prefix}-${random_pet.main.id}"
  })
}

# ===================================================================
# 🗄️ STORAGE & STATE MANAGEMENT
# ===================================================================

# Azure Storage Account for Terraform state
resource "azurerm_storage_account" "tfstate" {
  count                    = local.cloud_config.azure.enabled ? 1 : 0
  name                     = "tfstate${random_string.unique.result}"
  resource_group_name      = azurerm_resource_group.main[0].name
  location                 = azurerm_resource_group.main[0].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version         = "TLS1_2"
  allow_blob_public_access = false
  
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }
  
  tags = local.common_tags
}

resource "azurerm_storage_container" "tfstate" {
  count                = local.cloud_config.azure.enabled ? 1 : 0
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate[0].name
  container_access_type = "private"
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  count                = local.cloud_config.azure.enabled ? 1 : 0
  name                 = "cr${random_string.unique.result}"
  resource_group_name  = azurerm_resource_group.main[0].name
  location             = azurerm_resource_group.main[0].location
  sku                  = "Premium"
  admin_enabled        = false
  georeplication_locations = []
  
  network_rule_set {
    default_action = "Deny"
    virtual_network {
      action    = "Allow"
      subnet_id = module.vnet.subnet_ids["aks"]
    }
  }
  
  tags = local.common_tags
}

# AWS ECR (Elastic Container Registry)
resource "aws_ecr_repository" "main" {
  count                = local.cloud_config.aws.enabled ? 1 : 0
  name                 = "${local.resource_prefix}-repository"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = local.aws_resource_tags
}

# Google Container Registry
resource "google_container_registry" "main" {
  count    = local.cloud_config.gcp.enabled ? 1 : 0
  project  = data.google_project.current.project_id
  location = "US"
}

# ===================================================================
# 🔐 KEY MANAGEMENT & SECRETS
# ===================================================================

# Azure Key Vault
resource "azurerm_key_vault" "main" {
  count                       = local.cloud_config.azure.enabled ? 1 : 0
  name                        = "kv-${random_string.unique.result}"
  location                    = azurerm_resource_group.main[0].location
  resource_group_name         = azurerm_resource_group.main[0].name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true
  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [
      module.vnet.subnet_ids["aks"]
    ]
  }
  
  tags = local.common_tags
}

# AWS Secrets Manager (for container registry credentials)
resource "aws_secretsmanager_secret" "acr_credentials" {
  count       = local.cloud_config.aws.enabled ? 1 : 0
  name        = "${local.resource_prefix}-acr-credentials"
  description = "Container registry credentials for ${local.resource_prefix}"
  
  tags = local.aws_resource_tags
}

# AWS KMS Key for encryption
resource "aws_kms_key" "main" {
  count       = local.cloud_config.aws.enabled ? 1 : 0
  description = "KMS key for ${local.resource_prefix} resources"
  deletion_window_in_days = 7
  
  tags = local.aws_resource_tags
}

# Google Secret Manager
resource "google_secret_manager_secret" "main" {
  count     = local.cloud_config.gcp.enabled ? 1 : 0
  secret_id = "${local.resource_prefix}-secrets"
  project   = data.google_project.current.project_id
  
  replication {
    automatic = true
  }
  
  labels = {
    environment = var.environment
    project     = var.project_name
  }
}

# ===================================================================
# 🌐 NETWORKING INFRASTRUCTURE
# ===================================================================

# Virtual Network (Azure) / VPC (AWS) / Network (GCP)
module "vnet" {
  source = "./modules/networking"
  
  cloud_provider      = var.cloud_provider
  resource_group_name = try(azurerm_resource_group.main[0].name, "default")
  location           = var.location
  environment        = var.environment
  project_name       = var.project_name
  
  vnet_address_space = var.vnet_address_space
  subnets           = var.subnets
  
  tags = local.common_tags
  
  depends_on = [azurerm_resource_group.main]
}

# ===================================================================
  # ☸️ KUBERNETES CLUSTER
  # ===================================================================
  
  module "kubernetes" {
    source = "./modules/kubernetes"
    
    cloud_provider      = var.cloud_provider
    resource_group_name = try(azurerm_resource_group.main[0].name, "default")
    location           = var.location
    environment        = var.environment
    project_name       = var.project_name
    
    # Cluster configuration
    cluster_name       = var.cluster_name
    kubernetes_version = var.kubernetes_version
    
    # Network configuration
    vnet_id     = module.vnet.vnet_id
    subnet_id   = module.vnet.subnet_ids["aks"]
    network_plugin = var.network_plugin
    network_policy = var.network_policy
    
    # Node pool configuration
    default_node_pool_vm_size   = var.default_node_pool_vm_size
    default_node_pool_count     = var.default_node_pool_count
    enable_auto_scaling        = var.enable_auto_scaling
    min_node_count            = var.min_node_count
    max_node_count            = var.max_node_count
    
    # Security configuration
    enable_aad_rbac     = var.enable_aad_rbac
    aad_admin_group_ids = var.aad_admin_group_ids
    
    tags = local.common_tags
    
    depends_on = [module.vnet]
  }

# ===================================================================
# 📊 MONITORING & OBSERVABILITY INFRASTRUCTURE
# ===================================================================

# Log Analytics Workspace (Azure) / CloudWatch Log Group (AWS) / Logging (GCP)
module "monitoring" {
  source = "./modules/monitoring"
  
  cloud_provider      = var.cloud_provider
  resource_group_name = try(azurerm_resource_group.main[0].name, "default")
  location           = var.location
  environment        = var.environment
  project_name       = var.project_name
  
  # Cluster information
  cluster_id   = module.kubernetes.cluster_id
  cluster_name = module.kubernetes.cluster_name
  
  # Monitoring configuration
  prometheus_retention_days = var.prometheus_retention_days
  prometheus_storage_size   = var.prometheus_storage_size
  
  grafana_admin_password = var.grafana_admin_password
  grafana_replicas       = var.grafana_replicas
  
  # Storage configuration
  storage_account_name = try(azurerm_storage_account.monitoring[0].name, "")
  
  tags = local.common_tags
  
  depends_on = [module.kubernetes]
}

# ===================================================================
# 🤖 MACHINE LEARNING PLATFORM INFRASTRUCTURE
# ===================================================================

# ML Platform (MLflow, Jupyter, Model Serving)
module "ml_platform" {
  source = "./modules/ml-platform"
  
  cloud_provider      = var.cloud_provider
  resource_group_name = try(azurerm_resource_group.main[0].name, "default")
  location           = var.location
  environment        = var.environment
  project_name       = var.project_name
  
  # Cluster information
  cluster_id   = module.kubernetes.cluster_id
  cluster_name = module.kubernetes.cluster_name
  
  # ML configuration
  mlflow_tracking_uri  = var.mlflow_tracking_uri
  mlflow_artifact_store = var.mlflow_artifact_store
  
  # Storage configuration
  storage_account_name = try(azurerm_storage_account.ml_platform[0].name, "")
  
  tags = local.common_tags
  
  depends_on = [module.kubernetes]
}

# ===================================================================
# 🔐 IDENTITY & ACCESS MANAGEMENT
# ===================================================================

# Azure Active Directory Integration (when enabled)
resource "azurerm_role_assignment" "aks_admin" {
  count                = var.enable_aad_rbac && local.cloud_config.azure.enabled ? length(var.aad_admin_group_ids) : 0
  scope                = module.kubernetes.cluster_id
  role_definition_name = "Azure Kubernetes Service RBAC Admin"
  principal_id         = var.aad_admin_group_ids[count.index]
}

# Kubernetes RBAC (when not using AAD)
resource "kubernetes_cluster_role" "anomaly_detector_admin" {
  count = !var.enable_aad_rbac ? 1 : 0
  
  metadata {
    name = "anomaly-detector-admin"
    labels = local.common_tags
  }
  
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# ===================================================================
# 📊 OUTPUTS
# ===================================================================

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.kubernetes.cluster_name
}

output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = module.kubernetes.cluster_id
}

output "cluster_endpoint" {
  description = "Kubernetes cluster API endpoint"
  value       = module.kubernetes.cluster_endpoint
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw Kubernetes config"
  value       = module.kubernetes.kube_config_raw
  sensitive   = true
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = try(azurerm_resource_group.main[0].name, local.resource_prefix)
}

output "container_registry_name" {
  description = "Name of the container registry"
  value       = try(azurerm_container_registry.main[0].name, try(aws_ecr_repository.main[0].name, try(google_container_registry.main[0].id, "")))
}

output "container_registry_url" {
  description = "URL of the container registry"
  value       = try(azurerm_container_registry.main[0].login_server, try("${aws_ecr_repository.main[0].repository_url}", try("${data.google_project.current.project_id}.gcr.io", "")))
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = try(azurerm_key_vault.main[0].name, "")
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = module.monitoring.grafana_url
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = module.monitoring.prometheus_url
}

output "mlflow_tracking_url" {
  description = "MLflow tracking URL"
  value       = module.ml_platform.mlflow_tracking_url
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.vnet.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet IDs"
  value       = module.vnet.subnet_ids
}

output "storage_account_name" {
  description = "Storage account name"
  value       = try(azurerm_storage_account.tfstate[0].name, "")
}

output "random_suffix" {
  description = "Random suffix for resources"
  value       = random_pet.main.id
}