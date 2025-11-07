# modules/kubernetes/main.tf
# Kubernetes cluster module for AKS/EKS/GKE

# ===================================================================
# 📊 DATA SOURCES
# ===================================================================
data "azurerm_client_config" "current" {
  count = var.cloud_provider == "azure" ? 1 : 0
}

data "aws_caller_identity" "current" {
  count = var.cloud_provider == "aws" ? 1 : 0
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
    Module      = "kubernetes"
    Component   = "cluster"
    ManagedBy   = "Terraform"
  })
  
  # Resource naming
  cluster_name = "${var.project_name}-${var.environment}-cluster"
  
  # Cloud-specific configurations
  cloud_config = {
    azure = {
      enabled     = var.cloud_provider == "azure"
      identity_type = "SystemAssigned"
    }
    aws = {
      enabled     = var.cloud_provider == "aws"
      account_id  = try(data.aws_caller_identity.current[0].account_id, "")
    }
    gcp = {
      enabled    = var.cloud_provider == "gcp"
      project_id = try(data.google_project.current[0].project_id, "")
    }
  }
  
  # Node pool configuration
  node_pools = {
    system = {
      name                = "system"
      vm_size            = var.default_node_pool_vm_size
      node_count         = var.default_node_pool_count
      max_pods_per_node  = 110
      enable_auto_scaling = var.enable_auto_scaling
      min_count          = var.min_node_count
      max_count          = var.max_node_count
      taints             = []
      labels = {
        "node.kubernetes.io/node-pool" = "system"
        "workload-type"                 = "system"
      }
      tags = local.common_tags
    }
    
    # Optional: User node pool
    user = {
      name                = "user"
      vm_size            = var.default_node_pool_vm_size
      node_count         = 0  # Start with 0, scale as needed
      max_pods_per_node  = 110
      enable_auto_scaling = var.enable_auto_scaling
      min_count          = 0
      max_count          = var.max_node_count
      taints             = []
      labels = {
        "node.kubernetes.io/node-pool" = "user"
        "workload-type"                 = "user"
      }
      tags = local.common_tags
    }
    
    # Optional: ML node pool (if GPU enabled)
    ml = var.enable_ml_gpu ? {
      name                = "ml"
      vm_size            = var.ml_node_pool_vm_size
      node_count         = 0
      max_pods_per_node  = 110
      enable_auto_scaling = true
      min_count          = 0
      max_count          = 5
      taints = [
        {
          key    = "nvidia.com/gpu"
          value  = "present"
          effect = "NoSchedule"
        }
      ]
      labels = {
        "node.kubernetes.io/node-pool" = "ml"
        "workload-type"                 = "ml"
        "accelerator"                   = "nvidia-tesla-k80"
      }
      tags = local.common_tags
    } : null
  }
}

# ===================================================================
# 🔐 IDENTITY & ACCESS MANAGEMENT
# ===================================================================

# Azure AD Integration (Azure only)
resource "azurerm_kubernetes_cluster" "main" {
  count               = local.cloud_config.azure.enabled ? 1 : 0
  name                = local.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${local.cluster_name}-dns"
  kubernetes_version  = var.kubernetes_version
  
  # Identity configuration
  identity {
    type = local.cloud_config.azure.identity_type
  }
  
  # Default node pool
  default_node_pool {
    name                = local.node_pools.system.name
    node_count          = local.node_pools.system.node_count
    vm_size            = local.node_pools.system.vm_size
    max_pods           = local.node_pools.system.max_pods_per_node
    enable_auto_scaling = local.node_pools.system.enable_auto_scaling
    min_count          = local.node_pools.system.min_count
    max_count          = local.node_pools.system.max_count
    os_disk_size_gb    = 128
    vnet_subnet_id     = var.subnet_id
    
    # Node labels and taints
    node_labels = local.node_pools.system.labels
    node_taints = local.node_pools.system.taints
    
    # Availability zones
    zones = var.availability_zones
    
    # Enable host encryption
    enable_host_encryption = var.encryption_at_host_enabled
    
    # Enable node public IP (disabled for security)
    enable_node_public_ip = false
  }
  
  # Network configuration
  network_profile {
    network_plugin     = var.network_plugin
    network_policy     = var.network_policy
    service_cidr       = "10.2.0.0/16"
    dns_service_ip     = "10.2.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
  }
  
  # RBAC configuration
  role_based_access_control_enabled = true
  
  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = var.enable_aad_rbac
    admin_group_object_ids = var.enable_aad_rbac ? var.aad_admin_group_ids : []
  }
  
  # API server access
  api_server_authorized_ip_ranges = var.enable_private_cluster ? [] : ["0.0.0.0/0"]
  private_cluster_enabled         = var.enable_private_cluster
  private_cluster_public_fqdn_enabled = false
  
  # Maintenance window
  maintenance_window {
    allowed {
      day   = var.maintenance_window.day_of_week
      hours = [var.maintenance_window.start_time]
    }
    not_allowed {
      day   = "Saturday"
      hours = ["00:00", "23:59"]
    }
  }
  
  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = true
    max_graceful_termination_sec     = 600
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = 0.5
    scan_interval                    = "10s"
    skip_nodes_with_local_storage    = false
    skip_nodes_with_system_pods      = true
  }
  
  # Monitoring
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }
  
  # Microsoft Defender
  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
  
  # Tags
  tags = local.common_tags
  
  depends_on = [var.log_analytics_workspace_id]
}

# Additional node pools for Azure
resource "azurerm_kubernetes_cluster_node_pool" "additional" {
  for_each = { for k, v in local.node_pools : k => v if k != "system" && v != null && local.cloud_config.azure.enabled }
  
  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main[0].id
  vm_size              = each.value.vm_size
  node_count           = each.value.node_count
  max_pods             = each.value.max_pods_per_node
  enable_auto_scaling  = each.value.enable_auto_scaling
  min_count           = each.value.min_count
  max_count           = each.value.max_count
  vnet_subnet_id      = var.subnet_id
  os_disk_size_gb     = 128
  os_type             = "Linux"
  priority            = "Regular"
  eviction_policy     = "Delete"
  spot_max_price      = -1
  
  # Node labels and taints
  labels = each.value.labels
  taints = each.value.taints
  
  # Availability zones
  zones = var.availability_zones
  
  # Enable host encryption
  enable_host_encryption = var.encryption_at_host_enabled
  
  # Tags
  tags = each.value.tags
  
  lifecycle {
    ignore_changes = [
      node_count # Ignore changes from auto-scaler
    ]
  }
}

# AWS EKS Cluster
resource "aws_eks_cluster" "main" {
  count     = local.cloud_config.aws.enabled ? 1 : 0
  name      = local.cluster_name
  role_arn  = aws_iam_role.eks_cluster[0].arn
  version   = var.kubernetes_version
  
  # VPC configuration
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.enable_private_cluster
    endpoint_public_access  = !var.enable_private_cluster
    public_access_cidrs     = var.enable_private_cluster ? [] : ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster[0].id]
  }
  
  # Encryption configuration
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks[0].arn
    }
    resources = ["secrets"]
  }
  
  # Kubernetes network configuration
  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
  }
  
  # Enabled cluster log types
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Tags
  tags = local.common_tags
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
    aws_cloudwatch_log_group.eks_cluster[0],
  ]
}

# AWS EKS Node Groups
resource "aws_eks_node_group" "main" {
  for_each = { for k, v in local.node_pools : k => v if v != null && local.cloud_config.aws.enabled }
  
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.eks_node_group[each.key].arn
  subnet_ids      = var.subnet_ids
  instance_types  = [each.value.vm_size]
  
  # Scaling configuration
  scaling_config {
    desired_size = each.value.node_count
    max_size     = each.value.max_count
    min_size     = each.value.min_count
  }
  
  # Remote access
  remote_access {
    ec2_ssh_key = var.ssh_public_key != "" ? aws_key_pair.eks[0].key_name : null
    source_security_group_ids = [aws_security_group.eks_node_group[each.key].id]
  }
  
  # Update configuration
  update_config {
    max_unavailable_percentage = 25
  }
  
  # Labels
  labels = each.value.labels
  
  # Taints
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
  
  # Launch template
  launch_template {
    id      = aws_launch_template.eks_node_group[each.key].id
    version = "$Latest"
  }
  
  # Tags
  tags = each.value.tags
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]
}

# Google GKE Cluster
resource "google_container_cluster" "main" {
  count    = local.cloud_config.gcp.enabled ? 1 : 0
  name     = local.cluster_name
  location = var.location
  
  # Network configuration
  network    = var.vnet_name
  subnetwork = var.subnet_names["aks"]
  
  # Remove default node pool (we'll create custom ones)
  remove_default_node_pool = true
  initial_node_count       = 1
  
  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  }
  
  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = var.enable_private_cluster
    enable_private_endpoint = var.enable_private_cluster
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
  # Network policies
  network_policy {
    enabled = var.enable_network_policies
  }
  
  # Master version
  min_master_version = var.kubernetes_version
  
  # Cluster autoscaling
  cluster_autoscaling {
    enabled = var.enable_auto_scaling
    resource_limits {
      resource_type = "cpu"
      minimum       = var.min_node_count
      maximum       = var.max_node_count
    }
    resource_limits {
      resource_type = "memory"
      minimum       = var.min_node_count * 2
      maximum       = var.max_node_count * 8
    }
  }
  
  # Maintenance policy
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_window.start_time
    }
  }
  
  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = !var.enable_network_policies
    }
  }
  
  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = var.enable_monitoring
    }
  }
  
  # Release channel
  release_channel {
    channel = "REGULAR"
  }
  
  # Workload identity
  workload_identity_config {
    workload_pool = "${local.cloud_config.gcp.project_id}.svc.id.goog"
  }
  
  # Tags
  resource_labels = local.common_tags
  
  depends_on = [
    google_project_service.container_api,
    google_project_service.compute_api,
  ]
}

# Google GKE Node Pools
resource "google_container_node_pool" "main" {
  for_each = { for k, v in local.node_pools : k => v if v != null && local.cloud_config.gcp.enabled }
  
  name       = each.value.name
  cluster    = google_container_cluster.main[0].name
  location   = var.location
  node_count = each.value.enable_auto_scaling ? null : each.value.node_count
  
  # Autoscaling configuration
  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
    location_policy = "BALANCED"
  }
  
  # Node configuration
  node_config {
    machine_type = each.value.vm_size
    disk_size_gb = 100
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"
    
    # Service account
    service_account = google_service_account.gke_node[each.key].email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
    
    # Labels
    labels = each.value.labels
    
    # Tags
    tags = [each.key]
    
    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    
    # Workload metadata config
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    
    # Taints
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
    
    # GPU configuration (if applicable)
    dynamic "guest_accelerator" {
      for_each = contains(each.value.vm_size, "gpu") || contains(each.value.vm_size, "GPU") ? [1] : []
      content {
        type  = "nvidia-tesla-k80"
        count = 1
      }
    }
  }
  
  # Management configuration
  management {
    auto_repair  = true
    auto_upgrade = var.enable_automatic_upgrades
  }
  
  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
  
  # Node locations (availability zones)
  node_locations = var.availability_zones
  
  depends_on = [
    google_container_cluster.main,
    google_project_service.container_api,
  ]
}