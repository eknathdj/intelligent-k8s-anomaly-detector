# infrastructure/terraform/outputs.tf
# Terraform outputs for Intelligent Kubernetes Anomaly Detector

# ===================================================================
# ☸️ KUBERNETES CLUSTER OUTPUTS
# ===================================================================
output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.kubernetes.cluster_name
}

output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = module.kubernetes.cluster_id
}

output "cluster_endpoint" {
  description = "Kubernetes cluster API endpoint"
  value       = module.kubernetes.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64 encoded)"
  value       = module.kubernetes.cluster_ca_certificate
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate (base64 encoded)"
  value       = module.kubernetes.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key (base64 encoded)"
  value       = module.kubernetes.client_key
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw Kubernetes config for kubectl"
  value       = module.kubernetes.kube_config_raw
  sensitive   = true
}

output "node_resource_group" {
  description = "Resource group containing cluster nodes"
  value       = module.kubernetes.node_resource_group
}

# ===================================================================
# 🌐 NETWORKING OUTPUTS
# ===================================================================
output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.vnet.vnet_id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = module.vnet.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet IDs by name"
  value       = module.vnet.subnet_ids
}

output "subnet_names" {
  description = "Map of subnet names by key"
  value       = module.vnet.subnet_names
}

output "network_security_group_ids" {
  description = "Map of NSG IDs by subnet name"
  value       = module.vnet.network_security_group_ids
}

# ===================================================================
# 📊 MONITORING OUTPUTS
# ===================================================================
output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = module.monitoring.grafana_url
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = module.monitoring.prometheus_url
}

output "alertmanager_url" {
  description = "Alertmanager URL"
  value       = module.monitoring.alertmanager_url
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "prometheus_admin_password" {
  description = "Prometheus admin password"
  value       = module.monitoring.prometheus_admin_password
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = module.monitoring.log_analytics_workspace_id
}

# ===================================================================
# 🤖 ML PLATFORM OUTPUTS
# ===================================================================
output "mlflow_tracking_url" {
  description = "MLflow tracking server URL"
  value       = module.ml_platform.mlflow_tracking_url
}

output "mlflow_artifact_store" {
  description = "MLflow artifact store location"
  value       = var.mlflow_artifact_store
}

output "jupyter_hub_url" {
  description = "Jupyter Hub URL"
  value       = module.ml_platform.jupyter_hub_url
}

output "model_serving_endpoint" {
  description = "Model serving endpoint"
  value       = module.ml_platform.model_serving_endpoint
}

# ===================================================================
# 🔐 SECURITY OUTPUTS
# ===================================================================
output "key_vault_id" {
  description = "Key Vault ID"
  value       = try(azurerm_key_vault.main[0].id, "")
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = try(azurerm_key_vault.main[0].name, "")
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = try(azurerm_key_vault.main[0].vault_uri, "")
  sensitive   = true
}

output "container_registry_login_server" {
  description = "Container registry login server"
  value       = try(azurerm_container_registry.main[0].login_server, try("${aws_ecr_repository.main[0].repository_url}", try("${data.google_project.current.project_id}.gcr.io", "")))
}

output "container_registry_id" {
  description = "Container registry ID"
  value       = try(azurerm_container_registry.main[0].id, try(aws_ecr_repository.main[0].arn, try(google_container_registry.main[0].id, "")))
}

# ===================================================================
  # 📁 STORAGE OUTPUTS
  # ===================================================================
  output "storage_account_name" {
    description = "Storage account name for Terraform state"
    value       = try(azurerm_storage_account.tfstate[0].name, "")
  }
  
  output "storage_account_primary_endpoint" {
    description = "Storage account primary endpoint"
    value       = try(azurerm_storage_account.tfstate[0].primary_blob_endpoint, "")
    sensitive   = true
  }
  
  output "storage_container_name" {
    description = "Storage container name"
    value       = try(azurerm_storage_container.tfstate[0].name, "")
  }
  
  # ===================================================================
  # 🏷️ RESOURCE IDENTIFIERS
  # ===================================================================
  output "resource_group_name" {
    description = "Name of the resource group"
    value       = try(azurerm_resource_group.main[0].name, local.resource_prefix)
  }
  
  output "resource_group_id" {
    description = "ID of the resource group"
    value       = try(azurerm_resource_group.main[0].id, local.resource_prefix)
  }
  
  output "resource_group_location" {
    description = "Location of the resource group"
    value       = try(azurerm_resource_group.main[0].location, var.location)
  }
  
  output "random_suffix" {
    description = "Random suffix for resources"
    value       = random_pet.main.id
  }
  
  output "unique_string" {
    description = "Random unique string"
    value       = random_string.unique.result
  }
  
  # ===================================================================
  # 🔧 UTILITY OUTPUTS
  # ===================================================================
  output "common_tags" {
    description = "Common tags applied to all resources"
    value       = local.common_tags
  }
  
  output "cloud_provider_config" {
    description = "Cloud provider configuration"
    value       = local.cloud_config
  }
  
  output "infrastructure_ready" {
    description = "Indicates if infrastructure is ready for application deployment"
    value       = true
  }
  
  # ===================================================================
  # 📋 DEPLOYMENT INFORMATION
  # ===================================================================
  output "deployment_summary" {
    description = "Summary of deployed infrastructure"
    value = {
      cloud_provider = var.cloud_provider
      environment    = var.environment
      region         = var.location
      cluster_name   = module.kubernetes.cluster_name
      cluster_version = var.kubernetes_version
      node_count     = var.default_node_pool_count
      auto_scaling   = var.enable_auto_scaling
      monitoring     = var.enable_monitoring
      ml_platform    = var.enable_ml_platform
      security_features = {
        private_cluster     = var.enable_private_cluster
        network_policies    = var.enable_network_policies
        pod_security_policy = var.enable_pod_security_policy
        encryption_at_host  = var.encryption_at_host_enabled
      }
    }
  }
  
  output "next_steps" {
    description = "Next steps after infrastructure deployment"
    value = [
      "1. Configure kubectl: az aks get-credentials --resource-group ${try(azurerm_resource_group.main[0].name, local.resource_prefix)} --name ${module.kubernetes.cluster_name}",
      "2. Deploy applications: make deploy-application ENV=${var.environment}",
      "3. Access Grafana: ${module.monitoring.grafana_url}",
      "4. Access Prometheus: ${module.monitoring.prometheus_url}",
      "5. Access MLflow: ${module.ml_platform.mlflow_tracking_url}"
    ]
  }