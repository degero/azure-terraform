variable "name" {
  description = "Name of the Key Vault (must be globally unique, 3-24 alphanumeric chars)"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type    = string
  default = null
}

variable "sku_name" {
  description = "standard or premium"
  type        = string
  default     = "standard"
}

variable "purge_protection_enabled" {
  description = "Prevents permanent deletion of the vault or its secrets before the retention period expires. Recommended true for anything beyond throwaway testing."
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  type    = number
  default = 90
}

variable "network_default_action" {
  description = "Allow or Deny — default network access rule when no matching IP/subnet rule exists"
  type        = string
  default     = "Allow"
}

variable "allowed_ip_rules" {
  description = "List of IP ranges allowed when network_default_action is Deny"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "azurerm_client_config" "current" {}


resource "azurerm_key_vault" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name            = var.sku_name

  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days
  rbac_authorization_enabled = true
  network_acls {
    default_action = var.network_default_action
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_rules
  }

  tags = var.tags
}


resource "azurerm_role_assignment" "tf_keyvault_secrets" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

output "id" {
  value = azurerm_key_vault.this.id
}

output "vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "name" {
  value = azurerm_key_vault.this.name
}
