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
  default     = "Standard_LRS"
}


variable "replication_type" {
  description = "Replication for storage account."
  type        = string
  default     = "Standard_LRS"
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  tags                     = var.tags
}
