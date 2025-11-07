# infrastructure/terraform/versions.tf
# Provider version constraints

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
    google-beta = {
      source  = "hashicorp/google-beta"
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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Provider configurations
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    
    network {
      skip_provider_registration = false
    }
  }
  
  # Skip provider registration for faster deployment
  skip_provider_registration = false
  
  # Storage endpoint for Azure Government/China if needed
  # endpoint = var.azure_environment != "public" ? "https://${var.azure_environment}.management.azure.com" : null
}

provider "aws" {
  region = var.aws_region != "" ? var.aws_region : var.location
  
  default_tags {
    tags = local.aws_resource_tags
  }
  
  # Enable shared credentials file
  shared_credentials_files = []
  
  # Skip credentials validation for faster deployment
  skip_credentials_validation = false
  
  # Skip region validation for faster deployment  
  skip_region_validation = false
  
  # Skip requesting account data for faster deployment
  skip_requesting_account_id = false
}

provider "google" {
  project = var.gcp_project_id != "" ? var.gcp_project_id : try(data.google_project.current.project_id, "")
  region  = var.gcp_region != "" ? var.gcp_region : var.location
  
  # Enable requested services
  # services = ["container.googleapis.com", "compute.googleapis.com", "monitoring.googleapis.com"]
}

provider "google-beta" {
  project = var.gcp_project_id != "" ? var.gcp_project_id : try(data.google_project.current.project_id, "")
  region  = var.gcp_region != "" ? var.gcp_region : var.location
}

provider "kubernetes" {
  host                   = module.kubernetes.cluster_endpoint
  client_certificate     = base64decode(module.kubernetes.client_certificate)
  client_key             = base64decode(module.kubernetes.client_key)
  cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
  
  # Load config from kubeconfig file if available
  config_path = pathexpand("~/.kube/config")
  
  # Ignore certificate errors for self-signed certs
  # insecure = true  # Only for development!
}

provider "helm" {
  kubernetes {
    host                   = module.kubernetes.cluster_endpoint
    client_certificate     = base64decode(module.kubernetes.client_certificate)
    client_key             = base64decode(module.kubernetes.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
  }
}