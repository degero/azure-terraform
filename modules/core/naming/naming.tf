variable "environment" {
  description = "Environment short name, used in resource naming."
  type        = string
}

variable "projectname" {
  description = "Short project/workload name used in resource naming"
  type        = string
}

module "this" {
  source = "github.com/Azure/terraform-azurerm-naming?ref=a837381f6857dac19e0f43eff1ab39431dbb74c0"
  # version 0.4.3

  suffix = [var.projectname, var.environment]
}

output "all" {
  description = "All resource naming objects of this module"
  value       = module.this
}
