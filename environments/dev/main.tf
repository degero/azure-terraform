# keyvault

locals {
  name_prefix = "${var.projectname}-${var.environment}"

  common_tags = merge(var.tags, {
    environment = var.environment
    project     = var.projectname
    managed_by  = "terraform"
  })

}

module "naming" {
  source = "Azure/naming/azurerm"
  suffix = [var.projectname, var.environment]
}

module "rg" {
  source = "../../modules/core/rg"

  name     = module.naming.resource_group.name
  location = var.location

  tags = var.tags
}

# # keyvault
# module "keyvault" {
#   source = "../../modules/security/keyvault"

#   name                = module.naming.key_vault.name
#   resource_group_name = module.rg.name
#   location            = module.rg.location

#   tags = var.tags
# }


# # Linux webapp
# module "appservice" {
#   source = "../../modules/compute/appservice"

#   app_name            = var.projectname
#   environment         = var.environment
#   resource_group_name = module.rg.name
#   location            = module.rg.location

#   tags = var.tags
# }


# # Linux VM

# module "vm" {
#   source = "../../modules/compute/vm"

#   resource_group_name = module.rg.name
#   location            = module.rg.location
#   environment         = var.environment
#   admin_username      = var.vm_admin_username
#   app_name            = var.projectname
#   vm_os_sku           = var.vm_os_sku

#   tags = var.tags

# }

# resource "azurerm_key_vault_secret" "vm_admin_password" {
#   name             = "vm-admin-password"
#   value_wo         = module.vm.password
#   value_wo_version = 1
#   key_vault_id     = module.keyvault.id
# }
