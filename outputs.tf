output "resource_group_id" {
  value       = azurerm_resource_group.lab.id
  description = "RG ID"
}

output "vnet_id" {
  value       = module.records_spoke.vnet_id
  description = "VNet ID"
}

output "subnet_ids" {
  value       = module.records_spoke.subnet_ids
  description = "Subnet IDs"
}