# functions.tf

resource "azurerm_service_plan" "main" {
  name                = "${local.prefix}-plan"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption tier

  tags = var.tags
}

resource "random_string" "fnrt_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Storage account required by Function App runtime (separate from reports storage)
resource "azurerm_storage_account" "function_runtime" {
  name                     = "${replace(var.prefix, "-", "")}fnrt${random_string.fnrt_suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                = "${var.prefix}-func"
  location            = var.location
  resource_group_name = var.resource_group_name

  storage_account_name       = azurerm_storage_account.function_runtime.name
  storage_account_access_key = azurerm_storage_account.function_runtime.primary_access_key
  service_plan_id            = azurerm_service_plan.main.id

  virtual_network_subnet_id = var.virtual_network_subnet_id

  identity {
    type         = "UserAssigned"
    identity_ids = var.identity_ids
  }

  site_config {
    application_stack {
       python_version = "3.11"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"      = "python"
    "AZURE_CLIENT_ID"               = azurerm_user_assigned_identity.function.client_id
    "KEY_VAULT_URI"                 = azurerm_key_vault.main.vault_uri
    "REPORTS_STORAGE_ACCOUNT_NAME"  = azurerm_storage_account.main.name
    "SQL_CONNECTION_STRING_SECRET"  = azurerm_key_vault_secret.sql_connection_string.name
    "ACS_CONNECTION_STRING_SECRET"  = azurerm_key_vault_secret.acs_connection_string.name
    "ACS_SENDER_ADDRESS"            = "DoNotReply@${azurerm_email_communication_service_domain.main.from_sender_domain}"
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.function_kv_reader,
    azurerm_role_assignment.function_storage_contributor,
    azurerm_role_assignment.function_sql_contributor,
  ]
}
