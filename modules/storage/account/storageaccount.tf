variable "name" {
  description = "Name of the storage account."
  type        = string

}

variable "parent_id" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the storage account."
  type        = string
}

variable "account_tier" {
  description = "Tier for storage account."
  type        = string
  default     = "Standard"
}


variable "replication_type" {
  description = "Replication for storage account."
  type        = string
  default     = "LRS"
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}

terraform {
  required_providers {
    azapi   = { source = "Azure/azapi" }
    modtm   = { source = "Azure/modtm" }
    random  = { source = "hashicorp/random" }
    azurerm = { source = "hashicorp/azurerm" }
  }
}

module "this" {
  # version "0.10.0"
  source = "github.com/Azure/terraform-azurerm-avm-res-storage-storageaccount?ref=5695e5ec21744a3765051677d9e82bfba16b5d98"

  name                     = var.name
  parent_id                = var.parent_id
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type

  tags             = var.tags
  enable_telemetry = false
}

output "resource_id" {
  description = "Resource ID of the storage account."
  value       = module.this.resource_id
}

output "name" {
  description = "Name of the storage account."
  value       = module.this.name
}
