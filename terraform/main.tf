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

resource "azurerm_resource_group" "vault_test" {
  name     = "rg-vault-jenkins-project"
  location = "East US"
}