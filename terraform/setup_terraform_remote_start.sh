#!/bin/bash

az group create --name rg-tfstate --location westeurope
az storage account create --name sttfstatesparknhs --resource-group rg-tfstate --sku Standard_LRS
az storage container create --name tfstate --account-name sttfstatesparknhs
