variable "app_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "os_type" {
  type    = string
  default = "Linux"
}

variable "sku_name" {
  type    = string
  default = "B1"
}

variable "node_version" {
  type    = string
  default = "20-lts"
}

variable "tags" {
  description = "Tags applied to the resource group."
  type        = map(string)
  default     = {}
}


module "naming" {
  source = "Azure/naming/azurerm"
  suffix = [var.app_name, var.environment]
}


resource "azurerm_service_plan" "app" {
  name                = module.naming.app_service_plan.name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = var.os_type
  sku_name            = var.sku_name
  tags                = var.tags
}

resource "azurerm_linux_web_app" "app" {
  name                = module.naming.app_service.name
  resource_group_name = var.resource_group_name
  location            = azurerm_service_plan.app.location
  service_plan_id     = azurerm_service_plan.app.id
  tags                = var.tags

  site_config {
    application_stack {
      node_version = var.node_version
    }
  }
}

output "app_url" {
  value = azurerm_linux_web_app.app.default_hostname
}

output "service_plan_id" {
  value = azurerm_service_plan.app.id
}

output "web_app_id" {
  value = azurerm_linux_web_app.app.id
}
