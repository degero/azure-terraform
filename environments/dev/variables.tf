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

variable "ci_run" {
  type        = bool
  default     = false
  description = "Set to true by the CICD pipeline only."
}
