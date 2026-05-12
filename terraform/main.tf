# Configure the Azure provider
terraform {
  backend "azurerm" {
    resource_group_name = "rg-tfstate"
    storage_account_name = "sttfstatesparknhs"                              
    container_name       = "tfstate"                               
    key                  = "gp-prescribing.tfstate"              
  }
  required_providers {
    databricks = {
      source  = "databricks/databricks"      
      version = ">=1.0"

    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.43.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

provider "databricks" {
    host = azurerm_databricks_workspace.azure_databricks_workspace.workspace_url
}


resource "azurerm_resource_group" "spark_resource_group" {
  name     = "spark_resource_group"
  location = "westeurope"
}


resource "azurerm_storage_account" "storageaccount" {
  name                     = "nhssparkprojstorageacc"
  resource_group_name      = azurerm_resource_group.spark_resource_group.name
  location                 = azurerm_resource_group.spark_resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
}

resource "azurerm_storage_data_lake_gen2_filesystem" "raw" {
  name                  = "raw"
  storage_account_id    = azurerm_storage_account.storageaccount.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.storageaccount.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "silver" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.storageaccount.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "gold" {
  name                  = "gold"
  storage_account_id    = azurerm_storage_account.storageaccount.id
}

resource "azurerm_databricks_workspace" "azure_databricks_workspace" {
  name                = "azure_databricks_workspace"
  resource_group_name = azurerm_resource_group.spark_resource_group.name
  location            = azurerm_resource_group.spark_resource_group.location
  sku                 = "premium"
}

resource "azurerm_key_vault" "azurerm_key_vault" {
  name                        = "azurerm-key-vault"
  location                    = azurerm_resource_group.spark_resource_group.location
  resource_group_name         = azurerm_resource_group.spark_resource_group.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]

    storage_permissions = [
      "Get",
    ]
  }
}