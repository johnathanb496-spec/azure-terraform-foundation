resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  for_each              = toset(["hub", "records"])
  name                  = "link-blob-${each.key}"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = module.vnets[each.key].vnet_id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "records_blob" {
  name                = "pe-studentrecords-blob-${var.environment}-${var.location}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = module.vnets["records"].subnet_ids["snet-studentrecords-endpoint-${var.environment}-${var.location}"]

  private_service_connection {
    name                           = "psc-studentrecords-blob"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.records.id
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = var.tags
}