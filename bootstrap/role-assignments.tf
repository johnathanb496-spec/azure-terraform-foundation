resource "azurerm_role_assignment" "pipeline_rg_contributor" {
  scope                = azurerm_resource_group.lab.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.pipeline.object_id
}

resource "azurerm_role_assignment" "pipeline_state_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.pipeline.object_id
}

resource "azurerm_role_assignment" "me_state_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}