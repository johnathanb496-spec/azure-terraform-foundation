resource "azurerm_role_definition" "pipeline_deployer" {
  name        = "tf-pipeline-deployer"
  scope       = azurerm_resource_group.lab.id
  description = "Least-privilege role for the azure-terraform-foundation pipeline. Built from 403s."

  permissions {
    actions = [
      # Resource group: look up the lab RG (it's created in bootstrap, not by the pipeline)
      "Microsoft.Resources/subscriptions/resourceGroups/read",

      # Virtual networks: create/read/delete, plus attach to and peer them
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/write",
      "Microsoft.Network/virtualNetworks/delete",
      "Microsoft.Network/virtualNetworks/join/action",         # 403: DNS zone link attaches to a VNet
      "Microsoft.Network/virtualNetworks/peer/action",         # 403: peering needs permission on the remote VNet

      # Subnets: create/read/delete, plus attach to them
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/write",
      "Microsoft.Network/virtualNetworks/subnets/delete",
      "Microsoft.Network/virtualNetworks/subnets/join/action", # 403: private endpoint attaches to a subnet

      # VNet peerings
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",

      # Network security groups: create/read/delete, plus attach to subnets
      "Microsoft.Network/networkSecurityGroups/read",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Network/networkSecurityGroups/delete",
      "Microsoft.Network/networkSecurityGroups/join/action",   # 403: attaching an NSG to a subnet "joins" it

      # Private DNS zones
      "Microsoft.Network/privateDnsZones/read",
      "Microsoft.Network/privateDnsZones/write",
      "Microsoft.Network/privateDnsZones/delete",
      "Microsoft.Network/privateDnsZones/SOA/read",            # 403: provider reads the zone's SOA record after creating it

      # Private DNS zone links to VNets
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",

      # Private endpoints
      "Microsoft.Network/privateEndpoints/read",
      "Microsoft.Network/privateEndpoints/write",
      "Microsoft.Network/privateEndpoints/delete",
      "Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action",

      # Storage accounts: create/read/delete, plus the provider's readiness checks after creating one
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Storage/storageAccounts/delete",
      "Microsoft.Storage/storageAccounts/listKeys/action",     # 403: provider fetches the key to check blob service (replace later with storage_use_azuread)
      "Microsoft.Storage/storageAccounts/blobServices/read",   # 403: provider checks the blob service is ready
      "Microsoft.Storage/storageAccounts/fileServices/read",   # 403: provider checks the file service is ready

      # Blob containers (403 on read showed this type was missing from the seed; added full read/write/delete)
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/delete",

    
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