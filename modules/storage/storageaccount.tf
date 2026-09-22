variable "name" {
  description = "Name of the storage account."
  type        = string
}

variable "resource_group_name" {
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

module "this" {
  # version "0.10.0"
  source = "github.com/Azure/terraform-azurerm-avm-res-storage-storageaccount?ref=5695e5ec21744a3765051677d9e82bfba16b5d98"

  name                     = var.name
  parent_id                = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type

  tags = var.tags
}
