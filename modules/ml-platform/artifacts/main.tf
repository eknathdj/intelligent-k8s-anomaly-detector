locals {
  base_name = "${var.project_name}-${var.environment}-artifacts"
}

# ===== Azure Storage Account + Blob Container =====
resource "azurerm_storage_account" "main" {
  count                    = var.cloud_provider == "azure" ? 1 : 0
  name                     = replace(local.base_name, "-", "")   # 3-24 alnum
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  allow_blob_public_access = false
  tags = var.tags
}

resource "azurerm_storage_container" "main" {
  count                = var.cloud_provider == "azure" ? 1 : 0
  name                 = var.container_bucket
  storage_account_name = azurerm_storage_account.main[0].name
}

resource "azurerm_storage_management_policy" "main" {
  count              = var.cloud_provider == "azure" && var.retention_days > 0 ? 1 : 0
  storage_account_id = azurerm_storage_account.main[0].id
  rule {
    name    = "delete-old-artifacts"
    enabled = true
    filters {
      prefix_match = [var.container_bucket]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.retention_days
      }
    }
  }
}

# ===== AWS S3 Bucket =====
resource "aws_s3_bucket" "main" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  bucket = local.base_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "main" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  bucket = aws_s3_bucket.main[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count  = var.cloud_provider == "aws" && var.retention_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.main[0].id
  rule {
    id     = "delete-old"
    status = "Enabled"
    filter {} # whole bucket
    expiration {
      days = var.retention_days
    }
  }
}

# ===== Google Cloud Storage Bucket =====
resource "google_storage_bucket" "main" {
  count = var.cloud_provider == "gcp" ? 1 : 0
  name          = replace(local.base_name, "_", "-") # no underscore
  location      = var.location
  force_destroy = true
  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }
  versioning {
    enabled = true
  }
  labels = var.tags
}