resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.common_tags
}
