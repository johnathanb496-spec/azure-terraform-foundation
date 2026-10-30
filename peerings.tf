resource "azurerm_virtual_network_peering" "hub_to_records" {
  name                      = "peer-hub-to-records"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = module.vnets["hub"].vnet_name
  remote_virtual_network_id = module.vnets["records"].vnet_id

  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "records_to_hub" {
  name                      = "peer-records-to-hub"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = module.vnets["records"].vnet_name
  remote_virtual_network_id = module.vnets["hub"].vnet_id

  allow_virtual_network_access = true
}