resource "azurerm_network_security_group" "records" {
  name                = "nsg-studentrecords-endpoint"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
    location    = var.location
  })

  security_rule {
    name                       = "Allow-HTTPS-From-Studios"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = local.studio_address_prefixes
    destination_address_prefix = local.vnets["records"].subnets["snet-studentrecords-endpoint-${var.environment}-${var.location}"]
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "records" {
  subnet_id                 = module.vnets["records"].subnet_ids["snet-studentrecords-endpoint-${var.environment}-${var.location}"]
  network_security_group_id = azurerm_network_security_group.records.id
}

