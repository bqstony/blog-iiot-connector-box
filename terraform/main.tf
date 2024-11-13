// Version Handling:
// - ~> Allow greater patch versions 1.1.x
// - >= Any newer version allowed x.x.x
// - >= 1.9.0, < 2.0.0 Avoids major version updates
terraform {

  required_version = ">= 1.8.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.9.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>2.0.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6.3"
    }
  }

  backend "azurerm" {
    resource_group_name  = "iiot-euw-terraform-rg"
    storage_account_name = "iioteuwterraform"
    container_name       = "tfstate"
    key                  =  "dev.iiot.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  # ToDo: Update the subscription_id to your Azure Subscription ID
  subscription_id = "7414ceaf-31d7-409b-a014-71967d52edc0"
}

provider "azapi" {
}

// Used to access the current configuration of the AzureRM provider.
data "azurerm_client_config" "current" {
}