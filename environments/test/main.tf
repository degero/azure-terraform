# keyvault

locals {
  common_tags = merge(var.tags, {
    environment = var.environment
    project     = var.projectname
    managed_by  = "terraform"
  })

}


resource "terraform_data" "guard_default_workspace" {
  lifecycle {
    precondition {
      condition     = terraform.workspace != "default" || var.ci_run
      error_message = "The 'default' workspace is owned by CICD. Use your own workspace (terraform workspace new <name>)."
    }
  }
}

module "naming" {
  source = "../../modules/core/naming"

  projectname = var.projectname
  environment = var.environment
}

module "rg" {
  source = "../../modules/core/rg"

  name     = module.naming.all.resource_group.name
  location = var.location

  tags = local.common_tags
}

module "storage" {
  source = "../../modules/storage/account"

  name      = module.naming.all.storage_account.name
  parent_id = module.rg.resource_id
  location  = var.location

  tags = local.common_tags
}
