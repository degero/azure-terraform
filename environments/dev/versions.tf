terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.4.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
  }

  backend "azurerm" {}
}
