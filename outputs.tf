output "resource_group_id" {
  value       = azurerm_resource_group.lab.id
  description = "RG ID"
}

output "vnet_id" {
  value       = azurerm_virtual_network.lab.id
  description = "VNet ID"
}

output "subnet_app_id" {
  value       = azurerm_subnet.app.id
  description = "App subnet ID"
}

output "subnet_management_id" {
  value       = azurerm_subnet.management.id
  description = "Management subnet ID"
}

output "nsg_app_id" {
  value       = azurerm_network_security_group.app.id
  description = "App NSG ID"
}

output "nsg_management_id" {
  value       = azurerm_network_security_group.management.id
  description = "Management NSG ID"
}