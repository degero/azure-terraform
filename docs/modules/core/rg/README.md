### Requirements

No requirements.

### Providers

No providers.

### Modules

| Name | Source                                                             | Version                                  |
| ---- | ------------------------------------------------------------------ | ---------------------------------------- |
| this | github.com/Azure/terraform-azurerm-avm-res-resources-resourcegroup | 2c605230f1bcb5dc29a667f2a43258bfa9140c32 |

### Resources

No resources.

### Inputs

| Name     | Description                          | Type          | Default | Required |
| -------- | ------------------------------------ | ------------- | ------- | :------: |
| location | Azure region for the resource group. | `string`      | n/a     |   yes    |
| name     | Name of the resource group.          | `string`      | n/a     |   yes    |
| tags     | Tags applied to the resource group.  | `map(string)` | `{}`    |    no    |

### Outputs

| Name         | Description                        |
| ------------ | ---------------------------------- |
| name         | Name of the resource group.        |
| resource\_id | Resource ID of the resource group. |
