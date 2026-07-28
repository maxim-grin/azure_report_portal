resource "azurerm_api_management" "main" {
  name                = "${var.prefix}-apim"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.project
  publisher_email     = var.admin_email

  sku_name = "Consumption_0"

  tags = var.tags
}

resource "azurerm_api_management_api" "reports" {
  name                = "reports-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Reports API"
  path                = "reports"
  protocols           = ["https"]
}

resource "azurerm_api_management_api_operation" "get_report" {
  operation_id        = "get-report"
  api_name            = azurerm_api_management_api.reports.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Generate report"
  method              = "POST"
  url_template        = "/generate"
}

resource "azurerm_api_management_api_policy" "jwt_validation" {
  api_name            = azurerm_api_management_api.reports.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" require-expiration-time="true">
      <openid-config url="https://login.microsoftonline.com/${var.tenant_id}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>${var.client_id}</audience>
      </audiences>
      <issuers>
        <issuer>https://login.microsoftonline.com/${var.tenant_id}/v2.0</issuer>
      </issuers>
    </validate-jwt>
    <rate-limit calls="60" renewal-period="60" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
</policies>
XML
}
