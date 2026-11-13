### Requirements

No requirements.

### Providers

No providers.

### Modules

| Name | Source                                    | Version                                  |
| ---- | ----------------------------------------- | ---------------------------------------- |
| this | github.com/Azure/terraform-azurerm-naming | a837381f6857dac19e0f43eff1ab39431dbb74c0 |

### Resources

No resources.

### Inputs

| Name        | Description                                         | Type     | Default | Required |
| ----------- | --------------------------------------------------- | -------- | ------- | :------: |
| environment | Environment short name, used in resource naming.    | `string` | n/a     |   yes    |
| projectname | Short project/workload name used in resource naming | `string` | n/a     |   yes    |

### Outputs

| Name | Description                                |
| ---- | ------------------------------------------ |
| all  | All resource naming objects of this module |
