resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.workload}-${var.environment}-${var.location}"
  location = var.location
  tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
    location    = var.location
  })
}
