# keyvault

locals {
  common_tags = merge(var.tags, {
    environment = var.environment
    project     = var.projectname
    managed_by  = "terraform"
  })

}
#TODO move to core
module "naming" {
  source = "github.com/Azure/terraform-azurerm-naming?ref=a837381f6857dac19e0f43eff1ab39431dbb74c0"
  # version 0.4.3

  suffix = [var.projectname, var.environment]
}

module "rg" {
  source = "../../modules/core/rg"

  name     = module.naming.resource_group.name
  location = var.location

  tags = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  name                = module.naming.storage_account.name
  resource_group_name = module.rg.resource_id
  location            = var.location

  tags = local.common_tags
}
