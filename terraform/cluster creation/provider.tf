terraform {
  required_version = ">=0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  subscription_id = ""
  features {
    
  }
}


# Consider backup of statefile