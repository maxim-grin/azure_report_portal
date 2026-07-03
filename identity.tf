data "azuread_client_config" "current" {}

resource "azuread_application" "api" {
  display_name = "${local.prefix}-api"

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Allow the app to access reports on behalf of the signed-in user"
      admin_consent_display_name = "Access reports API"
      enabled                    = true
      id                         = "9ed1e6e8-1c4a-4f8b-9d3a-2f1e4c6b7a8d"
      type                       = "User"
      user_consent_description   = "Allow the app to access your reports"
      user_consent_display_name  = "Access reports"
      value                      = "Reports.Access"
    }
  }
}

resource "azuread_service_principal" "api" {
  client_id = azuread_application.api.client_id
}

resource "azuread_application_password" "api" {
  application_id = azuread_application.api.id
  display_name   = "terraform-managed"
  end_date       = timeadd(timestamp(), "8760h") # 1 year
}

# Managed identity for the Function App — created here, attached in functions.tf
resource "azurerm_user_assigned_identity" "function" {
  name                = "${local.prefix}-func-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}
