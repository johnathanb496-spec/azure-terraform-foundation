module "records_spoke" {
  source              = "./modules/network"
  name                = "vnet-records-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.0.0.0/24"]
  subnets = {
    "snet-studentrecords-endpoint-${var.environment}-${var.location}" = "10.0.0.0/27"
  }
  tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
    location    = var.location
  })
}

