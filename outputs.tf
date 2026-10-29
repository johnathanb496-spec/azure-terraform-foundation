output "resource_group_id" {
  value       = azurerm_resource_group.lab.id
  description = "RG ID"
}

output "subnet_ids" {
  value       = { for k, v in module.vnets : k => v.subnet_ids }
  description = "Subnet IDs"
}

output "vnet_ids" {
  value       = { for k, v in module.vnets : k => v.vnet_id }
  description = "VNet IDs by key"
}

