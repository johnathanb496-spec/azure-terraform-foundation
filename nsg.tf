#NSG default rules for app subnet
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${var.environment}-${var.location}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
    location    = var.location
  })
}

#NSG default rules for management subnet
resource "azurerm_network_security_group" "management" {
  name                = "nsg-management-${var.environment}-${var.location}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
    location    = var.location
  })
}

#NSG default rules for app subnet association
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

#NSG default rules for management subnet association
resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}