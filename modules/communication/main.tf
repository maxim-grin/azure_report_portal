resource "azurerm_communication_service" "main" {
  name                = "${var.prefix}-acs"
  resource_group_name = var.resource_group_name
  data_location        = var.data_location

  tags = var.tags
}

resource "azurerm_email_communication_service" "main" {
  name                = "${var.prefix}-acs-email"
  resource_group_name = var.resource_group_name
  data_location        = var.data_location

  tags = var.tags
}

resource "azurerm_email_communication_service_domain" "main" {
  name             = "AzureManagedDomain"
  email_service_id = azurerm_email_communication_service.main.id
  domain_management = "AzureManaged"
}

resource "azurerm_communication_service_email_domain_association" "main" {
  communication_service_id = azurerm_communication_service.main.id
  email_service_domain_id  = azurerm_email_communication_service_domain.main.id
}
