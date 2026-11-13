### Requirements

No requirements.

### Providers

No providers.

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | github.com/Azure/terraform-azurerm-avm-res-storage-storageaccount | 5695e5ec21744a3765051677d9e82bfba16b5d98 |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_tier"></a> [account\_tier](#input\_account\_tier) | Tier for storage account. | `string` | `"Standard"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the storage account. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the storage account. | `string` | n/a | yes |
| <a name="input_parent_id"></a> [parent\_id](#input\_parent\_id) | Name of the resource group. | `string` | n/a | yes |
| <a name="input_replication_type"></a> [replication\_type](#input\_replication\_type) | Replication for storage account. | `string` | `"LRS"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the storage account. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Name of the storage account. |
| <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id) | Resource ID of the storage account. |
