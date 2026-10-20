resource "azurerm_subnet" "app" {
  name                 = "snet-app-${var.environment}-${var.location}"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management-${var.environment}-${var.location}"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.0.64/26"]
}