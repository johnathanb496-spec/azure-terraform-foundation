# Configure Virtual Network
resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${var.workload}-${var.environment}-${var.location}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.0.0.0/24"]
  tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
    location    = var.location
  })
}