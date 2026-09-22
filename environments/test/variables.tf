# Variables
variable "environment" {
  description = "Environment short name, used in resource naming."
  type        = string
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
