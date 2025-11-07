# ---------------------------------------------------------------------------
#  modules/networking/outputs.tf
# ---------------------------------------------------------------------------

# ------- Cloud-Agnostic Network Identity -------
output "vpc_id" {
  description = "Cloud-native VPC/VNet ID (aws_vpc, azurerm_virtual_network, google_compute_network)."
  value = (
    var.cloud_provider == "azure" ? try(azurerm_virtual_network.main[0].id, null) :
    var.cloud_provider == "aws"   ? try(aws_vpc.main[0].id, null) :
    var.cloud_provider == "gcp"   ? try(google_compute_network.main[0].id, null) :
    null
  )
}

output "vpc_name" {
  description = "Human-readable VPC/VNet name."
  value = (
    var.cloud_provider == "azure" ? try(azurerm_virtual_network.main[0].name, null) :
    var.cloud_provider == "aws"   ? try(aws_vpc.main[0].tags["Name"], null) :
    var.cloud_provider == "gcp"   ? try(google_compute_network.main[0].name, null) :
    null
  )
}

# ------- Subnets -------
output "subnet_ids" {
  description = "Map of subnet keys to cloud-specific subnet IDs."
  value = (
    var.cloud_provider == "azure" ? { for k, v in azurerm_subnet.main : k => v.id } :
    var.cloud_provider == "aws"   ? { for k, v in aws_subnet.main : k => v.id } :
    var.cloud_provider == "gcp"   ? { for k, v in google_compute_subnetwork.main : k => v.id } :
    {}
  )
}

output "subnet_cidrs" {
  description = "Map of subnet keys to their CIDR strings."
  value = (
    var.cloud_provider == "azure" ? { for k, v in azurerm_subnet.main : k => v.address_prefixes[0] } :
    var.cloud_provider == "aws"   ? { for k, v in aws_subnet.main : k => v.cidr_block } :
    var.cloud_provider == "gcp"   ? { for k, v in google_compute_subnetwork.main : k => v.ip_cidr_range } :
    {}
  )
}

# ------- Security Groups / NSGs / Firewalls -------
output "security_group_ids" {
  description = "Map of subnet keys to security-group IDs (AWS) or NSG IDs (Azure) or empty on GCP."
  value = (
    var.cloud_provider == "azure" ? { for k, v in azurerm_network_security_group.main : k => v.id } :
    var.cloud_provider == "aws"   ? { for k, v in aws_security_group.main : k => v.id } :
    var.cloud_provider == "gcp"   ? {} : # GCP uses firewall rules, not SG resources
    {}
  )
}

# ------- Routing -------
output "route_table_ids" {
  description = "Map of subnet keys to route-table IDs (Azure) or single RT ID per subnet (AWS). Empty for GCP."
  value = (
    var.cloud_provider == "azure" ? { for k, v in azurerm_subnet_route_table_association.main : k => v.route_table_id } :
    var.cloud_provider == "aws"   ? { for k, v in aws_route_table.main : k => v.id } :
    {}
  )
}

# ------- Internet / NAT Gateways -------
output "internet_gateway_id" {
  description = "ID of the Internet Gateway (AWS only)."
  value       = var.cloud_provider == "aws" ? try(aws_internet_gateway.main[0].id, null) : null
}

output "nat_gateway_ids" {
  description = "Map of private subnet keys to NAT-gateway IDs (AWS only)."
  value = (
    var.cloud_provider == "aws" ?
    { for k, v in aws_nat_gateway.main : k => v.id } :
    {}
  )
}

# ------- Azure-Only Extras -------
output "ddos_protection_plan_id" {
  description = "ID of the Azure DDoS protection plan (if enabled)."
  value       = var.cloud_provider == "azure" ? try(azurerm_network_ddos_protection_plan.main[0].id, null) : null
}

output "application_gateway_id" {
  description = "ID of the Azure Application Gateway (if enabled)."
  value       = var.cloud_provider == "azure" ? try(azurerm_application_gateway.main[0].id, null) : null
}

output "private_dns_zone_ids" {
  description = "Map of Private DNS zone names to their resource IDs (Azure only)."
  value = (
    var.cloud_provider == "azure" ?
    { for k, v in azurerm_private_dns_zone.main : k => v.id } :
    {}
  )
}

# ------- GCP-Only Extras -------
output "router_id" {
  description = "Self-link of the GCP Cloud Router (if created)."
  value       = var.cloud_provider == "gcp" ? try(google_compute_router.main[0].id, null) : null
}

output "private_service_connect_address" {
  description = "IP address reserved for Private Service Connect (GCP only)."
  value = (
    var.cloud_provider == "gcp" && var.enable_private_service_connect ?
    try(google_compute_global_address.private_service_connect[0].address, null) :
    null
  )
}

# ------- Flow-Logs -------
output "flow_log_enabled" {
  description = "Boolean indicating whether flow logs are active."
  value = (
    (var.cloud_provider == "aws" && var.enable_flow_logs) ||
    (var.cloud_provider == "gcp" && var.enable_flow_logs) ||
    false
  )
}

output "flow_log_destination" {
  description = "CloudWatch Log-Group ARN (AWS) or subnet self-link (GCP) where flow logs are shipped."
  value = (
    var.cloud_provider == "aws" && var.enable_flow_logs ?
    try(aws_cloudwatch_log_group.vpc_flow_log[0].arn, null) :
    var.cloud_provider == "gcp" && var.enable_flow_logs ?
    try(values(google_compute_subnetwork.flow_logs)[0].self_link, null) :
    null
  )
}

# ------- Generic Helpers -------
output "cloud_provider" {
  description = "Provider that was active for this run (azure/aws/gcp)."
  value       = var.cloud_provider
}

output "resource_group_name" {
  description = "Resource group used (Azure only, otherwise null)."
  value       = var.cloud_provider == "azure" ? var.resource_group_name : null
}

output "region" {
  description = "Region/location string that was supplied."
  value       = var.location
}