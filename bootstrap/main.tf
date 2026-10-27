provider "azurerm" {
  features {}
}

terraform {
  required_version = "~> 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_resource_group" "rg-tfstate" {
  name     = "rg-tfstate"
  location = "southcentralus"
}



resource "azurerm_storage_account" "tfstate" {
  name                            = "sttfstatejb496"
  resource_group_name             = azurerm_resource_group.rg-tfstate.name
  location                        = azurerm_resource_group.rg-tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }
}


resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}