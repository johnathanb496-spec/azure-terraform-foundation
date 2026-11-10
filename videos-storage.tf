resource "azurerm_storage_account" "videos" {
  name                            = "stjbvideosdevscus"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = false
  account_kind                    = "StorageV2"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

  tags = merge(var.tags, {
    workload    = "lessonvideos"
    environment = var.environment
    location    = var.location
  })

}

resource "azurerm_storage_container" "videos" {
  name                  = "lesson-videos"
  storage_account_id    = azurerm_storage_account.videos.id
  container_access_type = "private"
}

