resource "azurerm_role_definition" "pipeline_deployer" {
  name        = "tf-pipeline-deployer"
  scope       = azurerm_resource_group.lab.id
  description = "Least-privilege role for the azure-terraform-foundation pipeline. Built from 403s."

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/write",
      "Microsoft.Network/virtualNetworks/delete",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/write",
      "Microsoft.Network/virtualNetworks/subnets/delete",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
      "Microsoft.Network/networkSecurityGroups/read",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Network/networkSecurityGroups/delete",
      "Microsoft.Network/privateDnsZones/read",
      "Microsoft.Network/privateDnsZones/write",
      "Microsoft.Network/privateDnsZones/delete",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",
      "Microsoft.Network/privateEndpoints/read",
      "Microsoft.Network/privateEndpoints/write",
      "Microsoft.Network/privateEndpoints/delete",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Storage/storageAccounts/delete",

      "Microsoft.Storage/storageAccounts/listKeys/action",     # provider fetches key to ensure blob service is ready
      "Microsoft.Network/privateDnsZones/SOA/read",            # provider reads SOA record for private DNS zone
      "Microsoft.Network/virtualNetworks/peer/action",         # needed to peer virtual networks
      "Microsoft.Storage/storageAccounts/blobServices/read",   # needed to read blob service settings after creating the account
      "Microsoft.Network/networkSecurityGroups/join/action",   # needed to join network security groups to subnets
    ]
    
    not_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.lab.id,
  ]
}

resource "azurerm_role_assignment" "pipeline_deployer" {
  scope              = azurerm_resource_group.lab.id
  role_definition_id = azurerm_role_definition.pipeline_deployer.role_definition_resource_id
  principal_id       = azuread_service_principal.pipeline.object_id
}