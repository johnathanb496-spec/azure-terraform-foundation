resource "azurerm_resource_group" "lab" {
  name     = "rg-networking-dev-southcentralus"
  location = "southcentralus"
  tags = {
    project     = "azure-terraform-foundation"
    workload    = "networking"
    environment = "dev"
    location    = "southcentralus"
  }
}
