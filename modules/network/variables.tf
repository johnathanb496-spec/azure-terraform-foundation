variable "name" {
  description = "Name of the resource"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Location of the resource"
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
}

variable "subnets" {
  description = "Map of subnet name to address prefix"
  type        = map(string)
}

variable "tags" {
  description = "Map of tags to assign to the resource"
  type        = map(string)
}