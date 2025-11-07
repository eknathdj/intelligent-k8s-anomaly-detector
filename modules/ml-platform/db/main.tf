locals {
  base_name = "${var.project_name}-${var.environment}-db"
}

# ===== Azure PostgreSQL Flexible Server =====
resource "azurerm_postgresql_flexible_server" "main" {
  count = var.cloud_provider == "azure" ? 1 : 0

  name                   = local.base_name
  location               = var.location
  resource_group_name    = var.resource_group_name
  version                = var.engine_version
  delegated_subnet_id    = var.subnet_ids["ml-platform"]
  private_dns_zone_id    = var.private_dns_zone_id != "" ? var.private_dns_zone_id : null
  administrator_login    = var.admin_username
  administrator_password = random_password.pwd[0].result
  backup_retention_days  = var.backup_retention_days
  storage_mb             = var.storage_mb
  sku_name               = var.sku_name
  ssl_enforcement_enabled= var.ssl_enforcement_enabled

  tags = var.tags
}

resource "random_password" "pwd" {
  count  = var.cloud_provider == "azure" && var.existing_password_secret == "" ? 1 : 0
  length = 32
  special = true
}

# ===== AWS RDS PostgreSQL =====
resource "aws_db_subnet_group" "main" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  name   = local.base_name
  subnet_ids = [for k, v in var.subnet_ids : v if k != "public"]
}

resource "aws_db_instance" "main" {
  count = var.cloud_provider == "aws" ? 1 : 0

  identifier             = local.base_name
  engine                 = "postgres"
  engine_version         = var.engine_version
  instance_class         = var.sku_name
  allocated_storage      = var.storage_mb / 1024
  max_allocated_storage  = (var.storage_mb / 1024) * 2
  backup_retention_period= var.backup_retention_days
  db_name                = "mlflow"
  username               = var.admin_username
  password               = random_password.pwd_aws[0].result
  vpc_security_group_ids = [aws_security_group.db[0].id]
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  skip_final_snapshot    = true
  publicly_accessible    = false
  tags = var.tags
}

resource "random_password" "pwd_aws" {
  count  = var.cloud_provider == "aws" && var.existing_password_secret == "" ? 1 : 0
  length = 32
  special = true
}

resource "aws_security_group" "db" {
  count = var.cloud_provider == "aws" ? 1 : 0
  name   = "${local.base_name}-sg"
  vpc_id = data.aws_vpc.selected[0].id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [for _, v in var.subnet_ids : cidrsubnet(v, 0, 0)]   # allow whole subnets
  }
  tags = var.tags
}

data "aws_vpc" "selected" {
  count = var.cloud_provider == "aws" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [values(var.subnet_ids)[0]]   # derive VPC from 1st subnet
  }
}

# ===== GCP CloudSQL PostgreSQL =====
resource "google_sql_database_instance" "main" {
  count = var.cloud_provider == "gcp" ? 1 : 0
  name             = replace(local.base_name, "-", "")   # no hyphens
  database_version = "POSTGRES_${var.engine_version}"
  region           = var.location
  settings {
    tier              = var.sku_name
    disk_size         = var.storage_mb / 1024
    disk_type         = "PD_SSD"
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      transaction_log_retention_days = var.backup_retention_days
    }
    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc[0].id
      ssl_mode        = var.ssl_enforcement_enabled ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED"
    }
  }
  deletion_protection = false
  tags = var.tags
}

resource "random_password" "pwd_gcp" {
  count  = var.cloud_provider == "gcp" && var.existing_password_secret == "" ? 1 : 0
  length = 32
  special = true
}

resource "google_sql_user" "admin" {
  count = var.cloud_provider == "gcp" ? 1 : 0
  name     = var.admin_username
  instance = google_sql_database_instance.main[0].name
  password = try(random_password.pwd_gcp[0].result, "supplied-by-secret")
}

data "google_compute_network" "vpc" {
  count = var.cloud_provider == "gcp" ? 1 : 0
  name  = split("/", values(var.subnet_ids)[0])[5]   # derive VPC from subnet self-link
}