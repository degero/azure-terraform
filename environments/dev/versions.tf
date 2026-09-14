terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.4.0"
    }
  }

  backend "azurerm" {}
  # if using TF Cloud remote store - backend "remote" {}
}
