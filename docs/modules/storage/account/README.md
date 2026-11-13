### Requirements

No requirements.

### Providers

No providers.

### Modules

| Name | Source | Version |
|------|--------|---------|
|  this | github.com/Azure/terraform-azurerm-avm-res-storage-storageaccount | 5695e5ec21744a3765051677d9e82bfba16b5d98 |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
|  account\_tier | Tier for storage account. | `string` | `"Standard"` | no |
|  location | Azure region for the storage account. | `string` | n/a | yes |
|  name | Name of the storage account. | `string` | n/a | yes |
|  parent\_id | Name of the resource group. | `string` | n/a | yes |
|  replication\_type | Replication for storage account. | `string` | `"LRS"` | no |
|  tags | Tags applied to the storage account. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
|  name | Name of the storage account. |
|  resource\_id | Resource ID of the storage account. |
