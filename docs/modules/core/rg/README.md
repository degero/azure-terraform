### Requirements

No requirements.

### Providers

No providers.

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | github.com/Azure/terraform-azurerm-avm-res-resources-resourcegroup | 2c605230f1bcb5dc29a667f2a43258bfa9140c32 |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | Azure region for the resource group. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource group. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the resource group. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Name of the resource group. |
| <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id) | Resource ID of the resource group. |
