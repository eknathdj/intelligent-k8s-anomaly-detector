output "fqdn" {
  value = (
    var.cloud_provider == "azure" ? try(azurerm_postgresql_flexible_server.main[0].fqdn, "") :
    var.cloud_provider == "aws"   ? try(aws_db_instance.main[0].endpoint, "") :
    var.cloud_provider == "gcp"   ? try(google_sql_database_instance.main[0].ip_address.0.ip_address, "") :
    ""
  )
}

output "password" {
  value = (
    var.cloud_provider == "azure" ? try(random_password.pwd[0].result, "") :
    var.cloud_provider == "aws"   ? try(random_password.pwd_aws[0].result, "") :
    var.cloud_provider == "gcp"   ? try(random_password.pwd_gcp[0].result, "") :
    ""
  )
  sensitive = true
}