terraform {
  required_version = ">=0.12"
  required_providers {
    azurerm = {
      version = "=3.0.0"
      source  = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {

  }
}


# Consider backup of statefile