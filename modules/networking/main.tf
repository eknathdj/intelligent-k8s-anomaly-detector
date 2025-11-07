# modules/networking/main.tf
# Multi-cloud networking module for Azure/AWS/GCP

# ===================================================================
# 📊 DATA SOURCES
# ===================================================================
data "azurerm_client_config" "current" {
  count = var.cloud_provider == "azure" ? 1 : 0
}

data "aws_availability_zones" "available" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  state  = "available"
}

data "google_project" "current" {
  count = var.cloud_provider == "gcp" ? 1 : 0
}

# ===================================================================
# 🏷️ LOCAL VALUES
# ===================================================================
locals {
  # Common tags for all resources
  common_tags = merge(var.tags, {
    Module      = "networking"
    Component   = "vnet"
    ManagedBy   = "Terraform"
  })
  
  # Resource naming
  base_name = "${var.project_name}-${var.environment}"
  
  # Cloud-specific configurations
  cloud_config = {
    azure = {
      enabled = var.cloud_provider == "azure"
      location = var.location
    }
    aws = {
      enabled = var.cloud_provider == "aws"
      region = var.location
      availability_zones = try(data.aws_availability_zones.available[0].names, [])
    }
    gcp = {
      enabled = var.cloud_provider == "gcp"
      project_id = try(data.google_project.current[0].project_id, "")
      region = var.location
    }
  }
  
  # Network segmentation for different workloads
  network_segments = {
    aks = {
      name = "aks"
      cidr = var.subnets["aks"].address_prefixes[0]
      purpose = "Kubernetes cluster nodes"
    }
    monitoring = {
      name = "monitoring"
      cidr = var.subnets["monitoring"].address_prefixes[0]
      purpose = "Monitoring infrastructure"
    }
    ml_platform = {
      name = "ml-platform"
      cidr = var.subnets["ml-platform"].address_prefixes[0]
      purpose = "ML platform services"
    }
  }
  
  # Security group rules (common across clouds)
  security_rules = {
    # Kubernetes API server
    kubernetes_api = {
      name        = "kubernetes-api"
      description = "Kubernetes API server"
      port        = 6443
      protocol    = "tcp"
      priority    = 100
    }
    
    # Node-to-node communication
    node_communication = {
      name        = "node-communication"
      description = "Node-to-node communication"
      port        = 0  # All ports
      protocol    = "tcp"
      priority    = 200
    }
    
    # Monitoring traffic
    monitoring = {
      name        = "monitoring"
      description = "Prometheus metrics scraping"
      port        = 9090
      protocol    = "tcp"
      priority    = 300
    }
    
    # Grafana
    grafana = {
      name        = "grafana"
      description = "Grafana dashboard"
      port        = 3000
      protocol    = "tcp"
      priority    = 400
    }
    
    # MLflow
    mlflow = {
      name        = "mlflow"
      description = "MLflow tracking server"
      port        = 5000
      protocol    = "tcp"
      priority    = 500
    }
    
    # Internal services
    internal_services = {
      name        = "internal-services"
      description = "Internal microservices"
      port        = 8080
      protocol    = "tcp"
      priority    = 600
    }
    
    # Health checks
    health_checks = {
      name        = "health-checks"
      description = "Health check endpoints"
      port        = 8081
      protocol    = "tcp"
      priority    = 700
    }
  }
}

# ===================================================================
# 🌐 AZURE VIRTUAL NETWORK
# ===================================================================

# Azure Virtual Network
resource "azurerm_virtual_network" "main" {
  count               = local.cloud_config.azure.enabled ? 1 : 0
  name                = "${local.base_name}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  
  # DNS servers (use Azure DNS by default)
  dns_servers = var.dns_servers
  
  # Enable DDoS protection (Premium tier)
  ddos_protection_plan {
    id     = try(azurerm_network_ddos_protection_plan.main[0].id, "")
    enable = var.enable_ddos_protection
  }
  
  tags = local.common_tags
}

# Azure Subnets
resource "azurerm_subnet" "main" {
  for_each = { for k, v in var.subnets : k => v if local.cloud_config.azure.enabled }
  
  name                 = "${local.base_name}-${each.key}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = each.value.address_prefixes
  
  # Service endpoints
  service_endpoints = each.value.service_endpoints
  
  # Private endpoint network policies
  private_endpoint_network_policies_enabled = each.value.private_endpoint_network_policies_enabled
  
  # Delegations
  dynamic "delegation" {
    for_each = each.value.delegations
    content {
      name = delegation.value
      service_delegation {
        name    = delegation.value
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
  
  lifecycle {
    ignore_changes = [
      # Ignore changes to network security group associations
      # as they're managed separately
    ]
  }
}

# Azure Network Security Groups
resource "azurerm_network_security_group" "main" {
  for_each = { for k, v in local.network_segments : k => v if local.cloud_config.azure.enabled }
  
  name                = "${local.base_name}-${each.key}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  tags = local.common_tags
}

# Azure NSG Security Rules
resource "azurerm_network_security_rule" "main" {
  for_each = { for segment_key, rule_key in setproduct(keys(local.network_segments), keys(local.security_rules)) : 
    "${segment_key}-${rule_key}" => {
      segment = local.network_segments[segment_key]
      rule    = local.security_rules[rule_key]
    } if local.cloud_config.azure.enabled
  }
  
  name                        = each.value.rule.name
  priority                    = each.value.rule.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = each.value.rule.protocol
  source_port_range           = "*"
  destination_port_range      = each.value.rule.port > 0 ? tostring(each.value.rule.port) : "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.main[each.value.segment.name].name
  description                 = each.value.rule.description
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = { for k, v in local.network_segments : k => v if local.cloud_config.azure.enabled }
  
  subnet_id                 = azurerm_subnet.main[each.key].id
  network_security_group_id = azurerm_network_security_group.main[each.key].id
}

# Azure Route Table
resource "azurerm_route_table" "main" {
  count               = local.cloud_config.azure.enabled ? 1 : 0
  name                = "${local.base_name}-rt"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  # Disable BGP route propagation
  disable_bgp_route_propagation = false
  
  tags = local.common_tags
}

# Associate route table with subnets
resource "azurerm_subnet_route_table_association" "main" {
  for_each = { for k, v in var.subnets : k => v if local.cloud_config.azure.enabled }
  
  subnet_id      = azurerm_subnet.main[each.key].id
  route_table_id = azurerm_route_table.main[0].id
}

# Azure Private DNS Zones
resource "azurerm_private_dns_zone" "main" {
  for_each = local.cloud_config.azure.enabled ? toset(["privatelink.azurewebsites.net", "privatelink.database.windows.net", "privatelink.blob.core.windows.net"]) : []
  
  name                = each.key
  resource_group_name = var.resource_group_name
  
  tags = local.common_tags
}

# Azure Private DNS Zone Virtual Network Links
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  for_each = local.cloud_config.azure.enabled ? toset(["privatelink.azurewebsites.net", "privatelink.database.windows.net", "privatelink.blob.core.windows.net"]) : []
  
  name                  = "${local.base_name}-${each.key}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main[each.key].name
  virtual_network_id    = azurerm_virtual_network.main[0].id
  registration_enabled  = true
  
  tags = local.common_tags
}

# Azure DDoS Protection Plan (optional)
resource "azurerm_network_ddos_protection_plan" "main" {
  count               = var.enable_ddos_protection && local.cloud_config.azure.enabled ? 1 : 0
  name                = "${local.base_name}-ddos-plan"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  tags = local.common_tags
}

# Azure Application Gateway (for ingress)
resource "azurerm_application_gateway" "main" {
  count               = var.enable_application_gateway && local.cloud_config.azure.enabled ? 1 : 0
  name                = "${local.base_name}-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }
  
  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_ids["appgateway"] != null ? var.subnet_ids["appgateway"] : azurerm_subnet.main["aks"].id
  }
  
  # Frontend IP configuration
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw[0].id
  }
  
  # Frontend port
  frontend_port {
    name = "http"
    port = 80
  }
  
  frontend_port {
    name = "https"
    port = 443
  }
  
  # Backend address pool
  backend_address_pool {
    name = "aks-backend-pool"
  }
  
  # Backend HTTP settings
  backend_http_settings {
    name                  = "aks-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }
  
  # HTTP listener
  http_listener {
    name                           = "aks-http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }
  
  # Request routing rule
  request_routing_rule {
    name                       = "aks-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "aks-http-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "aks-http-settings"
  }
  
  # Web Application Firewall (WAF) configuration
  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
  
  tags = local.common_tags
  
  depends_on = [azurerm_public_ip.appgw]
}

# Azure Public IP for Application Gateway
resource "azurerm_public_ip" "appgw" {
  count               = var.enable_application_gateway && local.cloud_config.azure.enabled ? 1 : 0
  name                = "${local.base_name}-appgw-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = local.common_tags
}

# ===================================================================
# 🟠 AWS VPC & NETWORKING
# ===================================================================

# AWS VPC
resource "aws_vpc" "main" {
  count      = local.cloud_config.aws.enabled ? 1 : 0
  cidr_block = var.vnet_address_space[0]
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # Enable DNS resolution for private endpoints
  enable_network_address_usage_metrics = true
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-vpc"
  })
}

# AWS Internet Gateway
resource "aws_internet_gateway" "main" {
  count  = local.cloud_config.aws.enabled ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-igw"
  })
}

# AWS Subnets
resource "aws_subnet" "main" {
  for_each = { for k, v in var.subnets : k => v if local.cloud_config.aws.enabled }
  
  vpc_id                  = aws_vpc.main[0].id
  cidr_block             = each.value.address_prefixes[0]
  availability_zone      = try(each.value.availability_zone, local.cloud_config.aws.availability_zones[index(keys(var.subnets), each.key) % length(local.cloud_config.aws.availability_zones)])
  map_public_ip_on_launch = each.key == "public" ? true : false
  
  # Enable DNS64 for IPv6 (if needed)
  enable_dns64 = false
  
  # Enable resource-based naming
  enable_resource_name_dns_a_record_on_launch = false
  
  # IPv6 configuration
  assign_ipv6_address_on_creation = false
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-${each.key}-subnet"
    "kubernetes.io/cluster/${local.base_name}-cluster" = "shared"  # For EKS
    "kubernetes.io/role/elb" = each.key == "public" ? "1" : ""     # For public ALB
    "kubernetes.io/role/internal-elb" = each.key != "public" ? "1" : ""  # For internal ALB
  })
}

# AWS Route Table
resource "aws_route_table" "main" {
  for_each = { for k, v in var.subnets : k => v if local.cloud_config.aws.enabled }
  
  vpc_id = aws_vpc.main[0].id
  
  # Route to Internet Gateway (for public subnets)
  dynamic "route" {
    for_each = each.key == "public" ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.main[0].id
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-${each.key}-rt"
  })
}

# AWS Route Table Associations
resource "aws_route_table_association" "main" {
  for_each = { for k, v in var.subnets : k => v if local.cloud_config.aws.enabled }
  
  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.main[each.key].id
}

# AWS Security Groups
resource "aws_security_group" "main" {
  for_each = { for k, v in local.network_segments : k => v if local.cloud_config.aws.enabled }
  
  name        = "${local.base_name}-${each.key}-sg"
  description = "Security group for ${each.key} subnet"
  vpc_id      = aws_vpc.main[0].id
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-${each.key}-sg"
  })
}

# AWS Security Group Rules
resource "aws_security_group_rule" "main" {
  for_each = { for segment_key, rule_key in setproduct(keys(local.network_segments), keys(local.security_rules)) : 
    "${segment_key}-${rule_key}" => {
      segment = local.network_segments[segment_key]
      rule    = local.security_rules[rule_key]
    } if local.cloud_config.aws.enabled
  }
  
  type              = "ingress"
  from_port         = each.value.rule.port > 0 ? each.value.rule.port : 0
  to_port           = each.value.rule.port > 0 ? each.value.rule.port : 65535
  protocol          = each.value.rule.protocol
  cidr_blocks       = [each.value.segment.cidr]
  security_group_id = aws_security_group.main[each.value.segment.name].id
  description       = each.value.rule.description
}

# AWS NAT Gateways (for private subnets)
resource "aws_nat_gateway" "main" {
  for_each = { for k, v in var.subnets : k => v if k != "public" && local.cloud_config.aws.enabled }
  
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.main["public"].id  # NAT Gateway goes in public subnet
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-${each.key}-nat"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# AWS Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  for_each = { for k, v in var.subnets : k => v if k != "public" && local.cloud_config.aws.enabled }
  
  domain = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-${each.key}-eip"
  })
}

# AWS NAT Gateway Routes
resource "aws_route" "nat" {
  for_each = { for k, v in var.subnets : k => v if k != "public" && local.cloud_config.aws.enabled }
  
  route_table_id         = aws_route_table.main[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}

# AWS VPC Endpoints (for private cluster communication)
resource "aws_vpc_endpoint" "main" {
  for_each = local.cloud_config.aws.enabled ? toset([
    "ec2", "ecr.api", "ecr.dkr", "s3", "logs", "sts", "iam"
  ]) : []
  
  vpc_id       = aws_vpc.main[0].id
  service_name = "com.amazonaws.${var.location}.${each.key}"
  
  # Route table IDs for gateway endpoints
  route_table_ids = each.key == "s3" || each.key == "dynamodb" ? 
    [for rt in aws_route_table.main : rt.id] : []
  
  # Security group for interface endpoints
  security_group_ids = each.key != "s3" && each.key != "dynamodb" ? 
    [aws_security_group.vpc_endpoint[0].id] : []
  
  # Private DNS enabled
  private_dns_enabled = true
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-${each.key}-endpoint"
  })
}

# AWS VPC Endpoint Security Group
resource "aws_security_group" "vpc_endpoint" {
  count  = local.cloud_config.aws.enabled ? 1 : 0
  name   = "${local.base_name}-vpc-endpoint-sg"
  vpc_id = aws_vpc.main[0].id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vnet_address_space[0]]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-vpc-endpoint-sg"
  })
}

# AWS Flow Logs for network monitoring
resource "aws_flow_log" "main" {
  count = var.enable_flow_logs && local.cloud_config.aws.enabled ? 1 : 0
  
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main[0].id
  
  log_destination_type = "cloud-watch-logs"
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-flow-log"
  })
}

# AWS CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count = var.enable_flow_logs && local.cloud_config.aws.enabled ? 1 : 0
  
  name              = "/aws/vpc/flowlog/${local.base_name}"
  retention_in_days = var.log_retention_days
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-vpc-flow-log"
  })
}

# ===================================================================
# 🟢 GOOGLE CLOUD VPC & NETWORKING
# ===================================================================

# Google VPC Network
resource "google_compute_network" "main" {
  count                   = local.cloud_config.gcp.enabled ? 1 : 0
  name                    = "${local.base_name}-vpc"
  auto_create_subnetworks = false  # Custom mode
  routing_mode            = "REGIONAL"
  
  # MTU setting
  mtu = 1460
  
  tags = local.common_tags
}

# Google Subnets
resource "google_compute_subnetwork" "main" {
  for_each = { for k, v in var.subnets : k => v if local.cloud_config.gcp.enabled }
  
  name                  = "${local.base_name}-${each.key}-subnet"
  ip_cidr_range        = each.value.address_prefixes[0]
  region               = var.location
  network              = google_compute_network.main[0].id
  private_ip_google_access = true  # Enable private Google access
  
  # Secondary IP ranges for GKE
  dynamic "secondary_ip_range" {
    for_each = each.key == "aks" ? [
      { range_name = "pods", ip_cidr_range = var.pod_cidr },
      { range_name = "services", ip_cidr_range = var.service_cidr }
    ] : []
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
  
  # Log config
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-${each.key}-subnet"
  })
}

# Google Firewall Rules
resource "google_compute_firewall" "main" {
  for_each = { for segment_key, rule_key in setproduct(keys(local.network_segments), keys(local.security_rules)) : 
    "${segment_key}-${rule_key}" => {
      segment = local.network_segments[segment_key]
      rule    = local.security_rules[rule_key]
    } if local.cloud_config.gcp.enabled
  }
  
  name    = "${local.base_name}-${each.value.segment.name}-${each.value.rule.name}"
  network = google_compute_network.main[0].id
  
  # Source and destination ranges
  source_ranges = [each.value.segment.cidr]
  target_tags   = [each.value.segment.name]
  
  allow {
    protocol = each.value.rule.protocol
    ports    = each.value.rule.port > 0 ? [tostring(each.value.rule.port)] : []
  }
  
  description = each.value.rule.description
  priority    = each.value.rule.priority
  
  # Enable logging
  enable_logging = true
  
  tags = local.common_tags
}

# Google Router (for NAT)
resource "google_compute_router" "main" {
  count    = local.cloud_config.gcp.enabled ? 1 : 0
  name     = "${local.base_name}-router"
  network  = google_compute_network.main[0].id
  region   = var.location
  
  tags = local.common_tags
}

# Google Router NAT (for private instances)
resource "google_compute_router_nat" "main" {
  for_each = { for k, v in var.subnets : k => v if k != "public" && local.cloud_config.gcp.enabled }
  
  name                               = "${local.base_name}-${each.key}-nat"
  router                             = google_compute_router.main[0].name
  region                             = var.location
  
  nat_ip_allocate_option = "AUTO_ONLY"
  
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.main[each.key].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  
  # Log config
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
  
  tags = local.common_tags
}

# Google VPC Flow Logs
resource "google_compute_subnetwork" "flow_logs" {
  for_each = { for k, v in var.subnets : k => v if var.enable_flow_logs && local.cloud_config.gcp.enabled }
  
  name                  = "${local.base_name}-${each.key}-subnet-flowlogs"
  ip_cidr_range        = each.value.address_prefixes[0]
  region               = var.location
  network              = google_compute_network.main[0].id
  private_ip_google_access = true
  
  # Enable flow logs
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.base_name}-${each.key}-subnet-flowlogs"
  })
}

# Google Private Service Connect (for private endpoints)
resource "google_compute_global_address" "private_service_connect" {
  count        = var.enable_private_service_connect && local.cloud_config.gcp.enabled ? 1 : 0
  name         = "${local.base_name}-psc-address"
  purpose      = "VPC_PEERING"
  address_type = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main[0].id
}

resource "google_service_networking_connection" "private_service_connect" {
  count                   = var.enable_private_service_connect && local.cloud_config.gcp.enabled ? 1 : 0
  network                 = google_compute_network.main[0].id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_connect[0].name]
}