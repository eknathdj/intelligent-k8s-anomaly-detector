output "bucket" {
  value = (
    var.cloud_provider == "azure" ? azurerm_storage_container.main[0].name :
    var.cloud_provider == "aws"   ? aws_s3_bucket.main[0].id :
    var.cloud_provider == "gcp"   ? google_storage_bucket.main[0].name :
    ""
  )
}

output "endpoint" {
  value = (
    var.cloud_provider == "azure" ? "https://${azurerm_storage_account.main[0].name}.blob.core.windows.net" :
    var.cloud_provider == "aws"   ? "https://s3.${var.location}.amazonaws.com" :
    var.cloud_provider == "gcp"   ? "https://storage.googleapis.com" :
    ""
  )
}

output "access_key" {
  value = (
    var.cloud_provider == "azure" ? azurerm_storage_account.main[0].name :
    var.cloud_provider == "aws"   ? data.aws_caller_identity.current[0].account_id :
    var.cloud_provider == "gcp"   ? "GOOG1E..."  # SA key created below
    : ""
  )
  sensitive = true
}

output "secret_key" {
  value = (
    var.cloud_provider == "azure" ? azurerm_storage_account.main[0].primary_access_key :
    var.cloud_provider == "aws"   ? data.aws_caller_identity.current[0].account_id : # placeholder – use IRSA later
    var.cloud_provider == "gcp"   ? google_service_account_key.artifacts[0].private_key :
    ""
  )
  sensitive = true
}

data "aws_caller_identity" "current" {
  count = var.cloud_provider == "aws" ? 1 : 0
}

# GCP SA + key (only if needed)
resource "google_service_account" "artifacts" {
  count = var.cloud_provider == "gcp" ? 1 : 0
  account_id   = "${var.project_name}-${var.environment}-artifacts"
  display_name = "MLflow artifacts access"
}

resource "google_service_account_key" "artifacts" {
  count = var.cloud_provider == "gcp" ? 1 : 0
  service_account_id = google_service_account.artifacts[0].name
}