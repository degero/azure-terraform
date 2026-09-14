variable "name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the resource group."
  type        = string
}

variable "tags" {
  description = "Tags applied to the resource group."
  type        = map(string)
  default     = {}
}

module "this" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  name     = var.name
  location = var.location

  tags = var.tags
}

output "resource_id" {
  description = "Resource ID of the resource group."
  value       = module.this.resource_id
}

output "name" {
  description = "Name of the resource group."
  value       = module.this.name
}
