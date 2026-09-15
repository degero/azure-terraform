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
  # version 0.4.0
  source = "github.com/Azure/terraform-azurerm-avm-res-resources-resourcegroup?ref=2c605230f1bcb5dc29a667f2a43258bfa9140c32"

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
