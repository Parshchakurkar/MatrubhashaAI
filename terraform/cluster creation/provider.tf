terraform {
  backend "azurerm" {
    storage_account_name = "demo"
    container_name = "demo"
    key = "demo"
  }
  required_version = ">=0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    
  }
}


# Consider backup of statefile