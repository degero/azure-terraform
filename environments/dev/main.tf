# keyvault

locals {
  common_tags = merge(var.tags, {
    environment = var.environment
    project     = var.projectname
    managed_by  = "terraform"
  })

}

module "naming" {
  source      = "Azure/naming/azurerm"
  version = "0.4.3"

  suffix = [var.projectname, var.environment]
}

module "rg" {
  source = "../../modules/core/rg"

  name     = module.naming.resource_group.name
  location = var.location

  tags = local.common_tags
}
