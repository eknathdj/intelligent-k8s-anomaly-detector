# modules/kubernetes/outputs.tf
# Outputs for Kubernetes cluster module

# ===================================================================
# ☸️ CLUSTER INFORMATION
# ===================================================================
output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].name, "") :
    var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].name, "") :
    var.cloud_provider == "gcp" ? try(google_container_cluster.main[0].name, "") :
    ""
  )
}

output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].id, "") :
    var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].id, "") :
    var.cloud_provider == "gcp" ? try(google_container_cluster.main[0].id, "") :
    ""
  )
}

output "cluster_endpoint" {
  description = "Kubernetes cluster API endpoint"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].kube_config[0].host, "") :
    var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].endpoint, "") :
    var.cloud_provider == "gcp" ? try("https://${google_container_cluster.main[0].endpoint}", "") :
    ""
  )
  sensitive = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64 encoded)"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].kube_config[0].cluster_ca_certificate, "") :
    var.cloud_provider == "aws" ? try(base64encode(aws_eks_cluster.main[0].certificate_authority[0].data), "") :
    var.cloud_provider == "gcp" ? try(base64encode(google_container_cluster.main[0].master_auth[0].cluster_ca_certificate), "") :
    ""
  )
  sensitive = true
}

output "client_certificate" {
  description = "Client certificate (base64 encoded)"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].kube_config[0].client_certificate, "") :
    var.cloud_provider == "aws" ? try(base64encode(aws_eks_cluster.main[0].certificate_authority[0].data), "") :
    var.cloud_provider == "gcp" ? try(base64encode(google_container_cluster.main[0].master_auth[0].client_certificate), "") :
    ""
  )
  sensitive = true
}

output "client_key" {
  description = "Client key (base64 encoded)"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].kube_config[0].client_key, "") :
    var.cloud_provider == "aws" ? try(base64encode(""), "") :  # AWS doesn't provide client key
    var.cloud_provider == "gcp" ? try(base64encode(google_container_cluster.main[0].master_auth[0].client_key), "") :
    ""
  )
  sensitive = true
}

output "kube_config_raw" {
  description = "Raw Kubernetes config for kubectl"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].kube_config_raw, "") :
    var.cloud_provider == "aws" ? try(local.eks_kubeconfig, "") :
    var.cloud_provider == "gcp" ? try(local.gke_kubeconfig, "") :
    ""
  )
  sensitive = true
}

# Local values for generating kubeconfig for AWS/GCP
locals {
  eks_kubeconfig = var.cloud_provider == "aws" && length(aws_eks_cluster.main) > 0 ? templatefile("${path.module}/templates/kubeconfig-eks.yaml", {
    cluster_name = aws_eks_cluster.main[0].name
    cluster_endpoint = aws_eks_cluster.main[0].endpoint
    cluster_ca_certificate = aws_eks_cluster.main[0].certificate_authority[0].data
    region = var.location
  }) : ""

  gke_kubeconfig = var.cloud_provider == "gcp" && length(google_container_cluster.main) > 0 ? templatefile("${path.module}/templates/kubeconfig-gke.yaml", {
    cluster_name = google_container_cluster.main[0].name
    cluster_endpoint = google_container_cluster.main[0].endpoint
    cluster_ca_certificate = google_container_cluster.main[0].master_auth[0].cluster_ca_certificate
    project_id = local.cloud_config.gcp.project_id
    region = var.location
  }) : ""
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].kubernetes_version, "") :
    var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].version, "") :
    var.cloud_provider == "gcp" ? try(google_container_cluster.main[0].min_master_version, "") :
    ""
  )
}

output "node_resource_group" {
  description = "Resource group containing cluster nodes (Azure only)"
  value = try(azurerm_kubernetes_cluster.main[0].node_resource_group, "")
}

# ===================================================================
# 🌐 NETWORKING OUTPUTS
# ===================================================================
output "cluster_endpoint" {
  description = "Cluster API server endpoint"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].fqdn, "") :
    var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].endpoint, "") :
    var.cloud_provider == "gcp" ? try(google_container_cluster.main[0].endpoint, "") :
    ""
  )
  sensitive = true
}

output "cluster_private_endpoint" {
  description = "Cluster private endpoint (if enabled)"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].private_fqdn, "") :
    var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].endpoint, "") :  # AWS uses same endpoint
    var.cloud_provider == "gcp" ? try(google_container_cluster.main[0].private_cluster_config[0].private_endpoint, "") :
    ""
  )
  sensitive = true
}

output "cluster_network_profile" {
  description = "Cluster network configuration"
  value = (
    var.cloud_provider == "azure" ? try({
      network_plugin = azurerm_kubernetes_cluster.main[0].network_profile[0].network_plugin
      network_policy = azurerm_kubernetes_cluster.main[0].network_profile[0].network_policy
      service_cidr   = azurerm_kubernetes_cluster.main[0].network_profile[0].service_cidr
      dns_service_ip = azurerm_kubernetes_cluster.main[0].network_profile[0].dns_service_ip
    }, {}) :
    var.cloud_provider == "aws" ? try({
      service_cidr = "172.20.0.0/16"  # Default for EKS
    }, {}) :
    var.cloud_provider == "gcp" ? try({
      services_cidr = google_container_cluster.main[0].cluster_ipv4_cidr
      pods_cidr     = google_container_cluster.main[0].services_ipv4_cidr
    }, {}) :
    {}
  )
}

output "subnet_ids_used" {
  description = "Subnet IDs used by the cluster"
  value = (
    var.cloud_provider == "azure" ? try([var.subnet_id], []) :
    var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].vpc_config[0].subnet_ids, []) :
    var.cloud_provider == "gcp" ? try([var.subnet_names["aks"]], []) :
    []
  )
}

# ===================================================================
# 🔐 SECURITY OUTPUTS
# ===================================================================
output "security_profile" {
  description = "Cluster security configuration"
  value = {
    private_cluster_enabled = var.enable_private_cluster
    network_policies_enabled = var.enable_network_policies
    encryption_at_host_enabled = var.encryption_at_host_enabled
    pod_security_standard = var.pod_security_standard
    workload_identity_enabled = var.enable_workload_identity
    pod_identity_enabled = var.enable_pod_identity
  }
}

output "rbac_enabled" {
  description = "Whether RBAC is enabled"
  value = true  # Always enabled in our configuration
}

output "aad_enabled" {
  description = "Whether Azure AD integration is enabled (Azure only)"
  value = var.enable_aad_rbac && var.cloud_provider == "azure"
}

output "identity_principal_id" {
  description = "Principal ID of the cluster identity"
  value = (
    var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].identity[0].principal_id, "") :
    var.cloud_provider == "aws" ? try(aws_iam_role.eks_cluster[0].arn, "") :
    var.cloud_provider == "gcp" ? try(google_service_account.gke_cluster[0].email, "") :
    ""
  )
  sensitive = true
}

# ===================================================================
# 📊 MONITORING & LOGGING OUTPUTS
# ===================================================================
output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value = var.enable_monitoring
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID (Azure only)"
  value = var.log_analytics_workspace_id
}

output "cluster_log_types" {
  description = "Types of logs being collected"
  value = var.cluster_log_types
}

output "cluster_metrics" {
  description = "Cluster metrics and endpoints"
  value = {
    prometheus_endpoint = var.enable_monitoring ? (
      var.cloud_provider == "azure" ? try("https://${azurerm_kubernetes_cluster.main[0].name}.monitoring.azure.com", "") :
      var.cloud_provider == "aws" ? try("https://${aws_eks_cluster.main[0].name}.eks.amazonaws.com/metrics", "") :
      var.cloud_provider == "gcp" ? try("https://monitoring.googleapis.com/v1/projects/${local.cloud_config.gcp.project_id}/clusters/${google_container_cluster.main[0].name}", "") :
      ""
    ) : ""
  }
}

# ===================================================================
# 🏗️ INFRASTRUCTURE DETAILS
# ===================================================================
output "node_pools" {
  description = "Information about all node pools"
  value = {
    for name, pool in local.node_pools : name => {
      name                = pool.name
      vm_size            = pool.vm_size
      node_count         = pool.node_count
      enable_auto_scaling = pool.enable_auto_scaling
      min_count          = pool.min_count
      max_count          = pool.max_count
      labels             = pool.labels
      taints             = pool.taints
    } if pool != null
  }
}

output "node_pool_ids" {
  description = "IDs of additional node pools"
  value = {
    for name, pool in local.node_pools : name => (
      var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster_node_pool.additional[name].id, "") :
      var.cloud_provider == "aws" ? try(aws_eks_node_group.main[name].id, "") :
      var.cloud_provider == "gcp" ? try(google_container_node_pool.main[name].id, "") :
      ""
    ) if pool != null && name != "system"
  }
}

output "auto_scaler_profile" {
  description = "Cluster autoscaler configuration"
  value = var.cluster_autoscaler_profile
}

# ===================================================================
# 🏢 CLOUD PROVIDER SPECIFIC OUTPUTS
# ===================================================================

# Azure AKS specific outputs
output "aks_details" {
  description = "Azure AKS specific details"
  value = var.cloud_provider == "azure" && length(azurerm_kubernetes_cluster.main) > 0 ? {
    fqdn                        = azurerm_kubernetes_cluster.main[0].fqdn
    private_fqdn               = try(azurerm_kubernetes_cluster.main[0].private_fqdn, "")
    node_resource_group        = azurerm_kubernetes_cluster.main[0].node_resource_group
    kubelet_identity_id        = try(azurerm_kubernetes_cluster.main[0].kubelet_identity[0].object_id, "")
    disk_encryption_set_id     = try(azurerm_kubernetes_cluster.main[0].disk_encryption_set_id, "")
    api_server_authorized_ip_ranges = try(azurerm_kubernetes_cluster.main[0].api_server_authorized_ip_ranges, [])
  } : null
}

# AWS EKS specific outputs
output "eks_details" {
  description = "AWS EKS specific details"
  value = var.cloud_provider == "aws" && length(aws_eks_cluster.main) > 0 ? {
    arn                    = aws_eks_cluster.main[0].arn
    certificate_authority  = aws_eks_cluster.main[0].certificate_authority[0].data
    platform_version       = aws_eks_cluster.main[0].platform_version
    status                 = aws_eks_cluster.main[0].status
    vpc_config             = aws_eks_cluster.main[0].vpc_config[0]
    enabled_log_types      = aws_eks_cluster.main[0].enabled_cluster_log_types
  } : null
}

# Google GKE specific outputs
output "gke_details" {
  description = "Google GKE specific details"
  value = var.cloud_provider == "gcp" && length(google_container_cluster.main) > 0 ? {
    location                  = google_container_cluster.main[0].location
    locations                 = google_container_cluster.main[0].locations
    master_version           = google_container_cluster.main[0].master_version
    current_master_version   = google_container_cluster.main[0].current_master_version
    current_node_version     = google_container_cluster.main[0].current_node_version
    services_ipv4_cidr       = google_container_cluster.main[0].services_ipv4_cidr
    cluster_ipv4_cidr        = google_container_cluster.main[0].cluster_ipv4_cidr
    master_authorized_networks_config = try(google_container_cluster.main[0].master_authorized_networks_config[0], {})
    private_cluster_config   = try(google_container_cluster.main[0].private_cluster_config[0], {})
    workload_identity_config = try(google_container_cluster.main[0].workload_identity_config[0], {})
  } : null
}

# ===================================================================
# 📋 DEPLOYMENT SUMMARY
# ===================================================================
output "deployment_summary" {
  description = "Summary of cluster deployment"
  value = {
    cloud_provider     = var.cloud_provider
    cluster_name       = local.cluster_name
    kubernetes_version = var.kubernetes_version
    environment        = var.environment
    location          = var.location
    node_count         = var.default_node_pool_count
    auto_scaling      = var.enable_auto_scaling
    private_cluster   = var.enable_private_cluster
    monitoring        = var.enable_monitoring
    security_features = {
      network_policies    = var.enable_network_policies
      encryption_at_host  = var.encryption_at_host_enabled
      pod_security        = var.pod_security_standard
      rbac_enabled        = true
    }
  }
}

output "kubeconfig_command" {
  description = "Command to get kubectl credentials"
  value = (
    var.cloud_provider == "azure" ? "az aks get-credentials --resource-group ${var.resource_group_name} --name ${local.cluster_name}" :
    var.cloud_provider == "aws" ? "aws eks update-kubeconfig --region ${var.location} --name ${local.cluster_name}" :
    var.cloud_provider == "gcp" ? "gcloud container clusters get-credentials ${local.cluster_name} --zone ${var.location} --project ${try(data.google_project.current[0].project_id, "")}" :
    ""
  )
}

output "next_steps" {
  description = "Next steps after cluster creation"
  value = [
    "1. Configure kubectl: ${self.kubeconfig_command}",
    "2. Verify cluster: kubectl get nodes",
    "3. Check system pods: kubectl get pods -n kube-system",
    "4. Deploy applications: make deploy-application ENV=${var.environment}",
    "5. Access dashboard: kubectl proxy"
  ]
}

# ===================================================================
# 🎯 HEALTH & STATUS OUTPUTS
# ===================================================================
output "cluster_health" {
  description = "Cluster health indicators"
  value = {
    provisioning_state = (
      var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].provisioning_state, "Unknown") :
      var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].status, "Unknown") :
      var.cloud_provider == "gcp" ? try(google_container_cluster.main[0].status, "Unknown") :
      "Unknown"
    )
    power_state = (
      var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].power_state, "Unknown") :
      "Running"  # AWS/GCP don't have power states
    )
    current_kubernetes_version = (
      var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].kubernetes_version, var.kubernetes_version) :
      var.cloud_provider == "aws" ? try(aws_eks_cluster.main[0].version, var.kubernetes_version) :
      var.cloud_provider == "gcp" ? try(google_container_cluster.main[0].current_master_version, var.kubernetes_version) :
      var.kubernetes_version
    )
  }
}

output "resource_utilization" {
  description = "Current resource utilization metrics"
  value = {
    node_count = (
      var.cloud_provider == "azure" ? try(azurerm_kubernetes_cluster.main[0].default_node_pool[0].node_count, var.default_node_pool_count) :
      var.cloud_provider == "aws" ? try(length(aws_eks_node_group.main), 1) :
      var.cloud_provider == "gcp" ? try(length(google_container_node_pool.main), 1) :
      var.default_node_pool_count
    )
    max_node_count = var.max_node_count
    current_pods = "Use kubectl to check: kubectl get pods --all-namespaces --no-headers | wc -l"
  }
}