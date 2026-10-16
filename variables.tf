variable "workload" {
  description = "networking resources workload"
  type        = string
  default     = "networking"
}

variable "location" {
  description = "location where the resources will be deployed"
  type        = string
  default     = "southcentralus"
}

variable "environment" {
  description = "environment"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "tags for the resources"
  type        = map(string)
  default = {
    project = "azure-terraform-foundation"
  }
}
