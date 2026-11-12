data "azurerm_resource_group" "lab" {
  name = "rg-${var.workload}-${var.environment}-${var.location}"
}
