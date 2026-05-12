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

resource "azuread_application" "sparkprojectapp" {
  display_name = "sparkprojectapp"
}

resource "azuread_service_principal" "sparkprojectappprincipal" {
  client_id = azuread_application.sparkprojectapp.client_id
}

resource "azuread_service_principal_password" "sparkprojectappprincipalpass" {
  service_principal_id = azuread_service_principal.sparkprojectappprincipal.id
  end_date = "2027-01-01T01:02:03Z"
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = azurerm_storage_account.storageaccount.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id        = azuread_service_principal.sparkprojectappprincipal.object_id
}

resource "azurerm_key_vault_secret" "sp-client-secret" {
  name         = "sp-client-secret"
  value        = azuread_service_principal_password.sparkprojectappprincipalpass.value
  key_vault_id = azurerm_key_vault.azurerm_key_vault.id
}

resource "databricks_secret_scope" "databricks-secret-scope" {
  name = "databricks-secret-scope"

  keyvault_metadata {
    resource_id = azurerm_key_vault.azurerm_key_vault.id
    dns_name    = azurerm_key_vault.azurerm_key_vault.vault_uri
  }
}


data "databricks_node_type" "smallest" {
  local_disk = true
}

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

resource "databricks_cluster" "shared_autoscaling" {
  cluster_name            = "Shared Autoscaling"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  num_workers = 0
  spark_conf = {
    # ADLS auth
    "fs.azure.account.auth.type.${azurerm_storage_account.storageaccount.name}.dfs.core.windows.net"            = "OAuth"
    "fs.azure.account.oauth.provider.type.${azurerm_storage_account.storageaccount.name}.dfs.core.windows.net"  = "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider"
    "fs.azure.account.oauth2.client.id.${azurerm_storage_account.storageaccount.name}.dfs.core.windows.net"     = "{{secrets/${databricks_secret_scope.databricks-secret-scope.name}/sp-client-id}}"
    "fs.azure.account.oauth2.client.secret.${azurerm_storage_account.storageaccount.name}.dfs.core.windows.net" = "{{secrets/${databricks_secret_scope.databricks-secret-scope.name}/sp-client-secret}}"
    "fs.azure.account.oauth2.client.endpoint.${azurerm_storage_account.storageaccount.name}.dfs.core.windows.net" = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/oauth2/token"

    # Single node
    "spark.master"                               = "local[*, 4]"
    "spark.databricks.cluster.profile"           = "singleNode"

    # Delta Lake
    "spark.sql.extensions"                       = "io.delta.sql.DeltaSparkSessionExtension"
    "spark.sql.catalog.spark_catalog"            = "org.apache.spark.sql.delta.catalog.DeltaCatalog"

    # AQE
    "spark.sql.adaptive.enabled"                 = "true"
    "spark.sql.adaptive.coalescePartitions.enabled" = "true"

    # Delta optimisations
    "spark.databricks.delta.optimizeWrite.enabled" = "true"
    "spark.databricks.delta.autoCompact.enabled"   = "true"
  }
  autotermination_minutes = 30
}

