resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.workload}-${var.environment}-${var.location}"
  location = var.location
  tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
    location    = var.location
  })
}


# Configure Virtual Network
resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${var.workload}-${var.environment}-${var.location}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.0.0.0/24"]
  tags = {
    environment = var.environment
  }
}

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
