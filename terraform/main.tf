terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  # No credentials here! Terraform reads ARM_CLIENT_ID, etc. from Vault.
}

# Get current Azure context for dynamic values
data "azurerm_client_config" "current" {}

# Local variables for resource naming
locals {
  resource_group_name = "rg-vault-jenkins-project"
  location            = "East US"
  environment         = "dev"
  project_name        = "vault-jenkins"
}

# ============================================================
# RESOURCE GROUP
# ============================================================
resource "azurerm_resource_group" "vault_test" {
  name     = local.resource_group_name
  location = local.location

  tags = {
    Environment = local.environment
    Project     = local.project_name
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# STORAGE ACCOUNT
# ============================================================
resource "azurerm_storage_account" "vault_storage" {
  name                     = "svault${replace(local.project_name, "-", "")}${formatdate("DDmmyy", timestamp())}"
  resource_group_name      = azurerm_resource_group.vault_test.name
  location                 = azurerm_resource_group.vault_test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }

  depends_on = [azurerm_resource_group.vault_test]
}

# Storage Container
resource "azurerm_storage_container" "vault_container" {
  name                  = "vault-data"
  storage_account_name  = azurerm_storage_account.vault_storage.name
  container_access_type = "private"
}

# ============================================================
# VIRTUAL NETWORK & SUBNET
# ============================================================
resource "azurerm_virtual_network" "vault_vnet" {
  name                = "vnet-${local.project_name}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.vault_test.location
  resource_group_name = azurerm_resource_group.vault_test.name

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }

  depends_on = [azurerm_resource_group.vault_test]
}

resource "azurerm_subnet" "vault_subnet" {
  name                 = "subnet-${local.project_name}"
  resource_group_name  = azurerm_resource_group.vault_test.name
  virtual_network_name = azurerm_virtual_network.vault_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ============================================================
# KEY VAULT (for production secret storage)
# ============================================================
resource "azurerm_key_vault" "vault_keyvault" {
  name                        = "kv-${local.project_name}-${formatdate("DDmmyy", timestamp())}"
  location                    = azurerm_resource_group.vault_test.location
  resource_group_name         = azurerm_resource_group.vault_test.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
    ]
  }

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }

  depends_on = [azurerm_resource_group.vault_test]
}

# ============================================================
# LOG ANALYTICS WORKSPACE (for monitoring)
# ============================================================
resource "azurerm_log_analytics_workspace" "vault_logs" {
  name                = "law-${local.project_name}"
  location            = azurerm_resource_group.vault_test.location
  resource_group_name = azurerm_resource_group.vault_test.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }

  depends_on = [azurerm_resource_group.vault_test]
}

# ============================================================
# APPLICATION INSIGHTS (for monitoring)
# ============================================================
resource "azurerm_application_insights" "vault_appinsights" {
  name                = "ai-${local.project_name}"
  location            = azurerm_resource_group.vault_test.location
  resource_group_name = azurerm_resource_group.vault_test.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.vault_logs.id

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }

  depends_on = [azurerm_log_analytics_workspace.vault_logs]
}

# ============================================================
# OUTPUTS
# ============================================================
output "resource_group_name" {
  value       = azurerm_resource_group.vault_test.name
  description = "Name of the created resource group"
}

output "storage_account_name" {
  value       = azurerm_storage_account.vault_storage.name
  description = "Name of the created storage account"
}

output "key_vault_id" {
  value       = azurerm_key_vault.vault_keyvault.id
  description = "ID of the created Key Vault"
}

output "key_vault_uri" {
  value       = azurerm_key_vault.vault_keyvault.vault_uri
  description = "URI of the created Key Vault"
}

output "vnet_id" {
  value       = azurerm_virtual_network.vault_vnet.id
  description = "ID of the created Virtual Network"
}

output "subnet_id" {
  value       = azurerm_subnet.vault_subnet.id
  description = "ID of the created Subnet"
}

output "app_insights_instrumentation_key" {
  value       = azurerm_application_insights.vault_appinsights.instrumentation_key
  description = "Instrumentation key for Application Insights"
  sensitive   = true
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.vault_logs.workspace_id
  description = "Workspace ID of Log Analytics"
}