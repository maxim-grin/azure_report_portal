resource "azurerm_communication_service" "main" {
  name                = "${local.prefix}-acs"
  resource_group_name = azurerm_resource_group.main.name
  data_location        = "United States"

  tags = local.common_tags
}

resource "azurerm_email_communication_service" "main" {
  name                = "${local.prefix}-acs-email"
  resource_group_name = azurerm_resource_group.main.name
  data_location        = "United States"

  tags = local.common_tags
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
