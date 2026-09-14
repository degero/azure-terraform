# Variables
variable "environment" {
  description = "Environment short name, used in resource naming."
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

variable "projectname" {
  description = "Short project/workload name used in resource naming"
  type        = string
}

variable "location" {
  type    = string
  default = "australiaeast"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "vm_admin_username" {
  type        = string
  description = "Admin user for the VM"
  default     = "azureuser"
  sensitive   = true
}

# Lookups
variable "vm_os_sku" {
  default = {
    westus2       = "16.04-LTS"
    eastus        = "18.04-LTS"
    australiaeast = "16.04-LTS"
    southeastasia = "16.04-LTS"
  }
}
