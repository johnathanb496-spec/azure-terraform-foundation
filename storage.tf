locals {
  records_storage_name = "stjbrecords${var.environment}scus"
}


resource "azurerm_storage_account" "records" {
  name                     = local.records_storage_name
  resource_group_name      = data.azurerm_resource_group.lab.name
  location                 = data.azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  tags = merge(var.tags, {
    workload    = "studentrecords"
    environment = var.environment
    location    = var.location
  })
}

