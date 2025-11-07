# infrastructure/terraform/backend.tf
# Remote state backend configuration - SIMPLIFIED VERSION

# ===================================================================
# 📝 BACKEND CONFIGURATION
# ===================================================================
# This file defines the backend configuration structure.
# Actual backend settings are provided at runtime via backend.conf
# ===================================================================

terraform {
  # Backend configuration will be provided at runtime
  # This prevents hardcoding sensitive information
}

# ===================================================================
# 📋 BACKEND SETUP INSTRUCTIONS
# ===================================================================
# 
# BEFORE RUNNING TERRAFORM:
# 1. Choose your cloud provider backend
# 2. Create backend.conf file (see templates below)
# 3. Run: terraform init -backend-config=backend.conf
#
# TEMPLATES FOR backend.conf:
#
# 🔵 AZURE:
# resource_group_name  = "rg-aiops-tfstate"
# storage_account_name = "tfstateaiops001"
# container_name       = "tfstate"
# key                  = "prod.terraform.tfstate"
#
# 🟠 AWS:
# bucket         = "tfstate-aiops-prod"
# key            = "prod.terraform.tfstate"
# region         = "us-east-1"
# dynamodb_table = "tfstate-aiops-prod-lock"
# encrypt        = true
#
# 🟢 GCP:
# bucket = "tfstate-aiops-prod"
# prefix = "prod"
#
# ===================================================================

# ===================================================================
# 🔒 SECURITY VALIDATION (Optional)
# ===================================================================

# Simple validation that backend config exists
locals {
  has_backend_config = fileexists("${path.module}/backend.conf")
}

# Warning if no backend configured
resource "null_resource" "backend_warning" {
  count = local.has_backend_config ? 0 : 1
  
  provisioner "local-exec" {
    command = "echo '⚠️  WARNING: No backend.conf found. Using local state (not recommended for production!)'"
  }
}

# ===================================================================
# 📊 OUTPUT INFORMATION
# ===================================================================

output "backend_status" {
  description = "Backend configuration status"
  value = {
    configured = local.has_backend_config
    message    = local.has_backend_config ? "✅ Backend configured via backend.conf" : "⚠️  Using local state - create backend.conf for production"
  }
}

output "backend_setup_instructions" {
  description = "Instructions for setting up backend"
  value = <<-EOT
    
    📋 BACKEND SETUP INSTRUCTIONS:
    
    1. Choose your cloud provider and create backend.conf:
    
    AZURE (create backend.conf):
    resource_group_name  = "your-resource-group"
    storage_account_name = "your-storage-account"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
    
    AWS (create backend.conf):
    bucket         = "your-s3-bucket"
    key            = "prod.terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-lock-table"
    encrypt        = true
    
    GCP (create backend.conf):
    bucket = "your-gcs-bucket"
    prefix = "prod"
    
    2. Run: terraform init -backend-config=backend.conf
    
    3. Continue with: terraform plan
    
  EOT
}