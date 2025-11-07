variable "cloud_provider" {}   # azure | aws | gcp
variable "project_name" {}
variable "environment" {}
variable "location" {}
variable "resource_group_name" {} # Azure only
variable "subnet_ids" {}          # map<string,string>
variable "tags" {}

variable "sku_name" {}
variable "engine_version" {}
variable "storage_mb" {}
variable "backup_retention_days" {}
variable "admin_username" {}
variable "ssl_enforcement_enabled" {}
variable "existing_password_secret" {}