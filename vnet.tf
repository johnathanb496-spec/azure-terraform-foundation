locals {
  vnets = {
    records = {
      name          = "vnet-records-${var.environment}-${var.location}"
      address_space = ["10.0.0.0/24"]
      subnets = {
        "snet-studentrecords-endpoint-${var.environment}-${var.location}" = "10.0.0.0/27"
      }
    }
    hub = {
      name          = "vnet-hub-${var.environment}-${var.location}"
      address_space = ["10.1.0.0/24"]
      subnets = {
        "AzureFirewallSubnet"           = "10.1.0.0/26"
        "AzureFirewallManagementSubnet" = "10.1.0.64/26"
        "GatewaySubnet"                 = "10.1.0.128/27"
      }
    }
  }
}


module "vnets" {
  source   = "./modules/network"
  for_each = local.vnets

  name                = each.value.name
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = each.value.address_space
  subnets             = each.value.subnets
  tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
    location    = var.location
  })
}

