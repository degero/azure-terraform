<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version  |
| ------------------------------------------------------------------------ | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.7   |
| <a name="requirement_azapi"></a> [azapi](#requirement_azapi)             | ~> 2.4   |
| <a name="requirement_azurerm"></a> [azurerm](#requirement_azurerm)       | >= 5.4.0 |

## Providers

No providers.

## Modules

| Name                                                     | Source                                    | Version                                  |
| -------------------------------------------------------- | ----------------------------------------- | ---------------------------------------- |
| <a name="module_naming"></a> [naming](#module_naming)    | github.com/Azure/terraform-azurerm-naming | a837381f6857dac19e0f43eff1ab39431dbb74c0 |
| <a name="module_rg"></a> [rg](#module_rg)                | ../../modules/core/rg                     | n/a                                      |
| <a name="module_storage"></a> [storage](#module_storage) | ../../modules/storage                     | n/a                                      |

## Resources

No resources.

## Inputs

| Name                                                               | Description                                         | Type          | Default           | Required |
| ------------------------------------------------------------------ | --------------------------------------------------- | ------------- | ----------------- | :------: |
| <a name="input_environment"></a> [environment](#input_environment) | Environment short name, used in resource naming.    | `string`      | n/a               |   yes    |
| <a name="input_location"></a> [location](#input_location)          | n/a                                                 | `string`      | `"australiaeast"` |    no    |
| <a name="input_projectname"></a> [projectname](#input_projectname) | Short project/workload name used in resource naming | `string`      | n/a               |   yes    |
| <a name="input_tags"></a> [tags](#input_tags)                      | Common tags applied to all resources.               | `map(string)` | `{}`              |    no    |

## Outputs

| Name                                                      | Description |
| --------------------------------------------------------- | ----------- |
| <a name="output_rg_name"></a> [rg\_name](#output_rg_name) | n/a         |

<!-- END_TF_DOCS -->
