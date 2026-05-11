# Configure the Azure provider
terraform {
  backend "azurerm" {
    storage_account_name = "sttfstatesparknhs"                              
    container_name       = "tfstate"                               
    key                  = "gp-prescribing.tfstate"              
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "spark_resource_group"
  location = "westeurope"
}
