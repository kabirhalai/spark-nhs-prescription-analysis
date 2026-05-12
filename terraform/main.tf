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

provider "databricks" {
    host = azurerm_databricks_workspace.azure_databricks_workspace.workspace_url
}


resource "azurerm_resource_group" "spark_resource_group" {
  name     = "spark_resource_group"
  location = "westeurope"
}


resource "azurerm_storage_account" "storageaccount" {
  name                     = "sparkstorageaccount"
  resource_group_name      = azurerm_resource_group.spark_resource_group.name
  location                 = azurerm_resource_group.spark_resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
}

resource "azurerm_storage_data_lake_gen2_filesystem" "data_lake" {
  name               = "spark-data-lake"
  storage_account_id = azurerm_storage_account.storageaccount.id
}

resource "azurerm_storage_container" "raw" {
  name                  = "raw"
  storage_account_id    = azurerm_storage_account.storageaccount.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.storageaccount.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.storageaccount.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "gold" {
  name                  = "gold"
  storage_account_id    = azurerm_storage_account.storageaccount.id
  container_access_type = "private"
}

resource "azurerm_databricks_workspace" "azure_databricks_workspace" {
  name                = "azure_databricks_workspace"
  resource_group_name = azurerm_resource_group.spark_resource_group.name
  location            = azurerm_resource_group.spark_resource_group.location
  sku                 = "premium"
}

