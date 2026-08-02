# functions.tf

resource "azurerm_service_plan" "main" {
  #checkov:skip=CKV_AZURE_225:Classic Consumption (Y1) plans don't support availability zones at all — requires Elastic Premium or Dedicated. Accepted for a Consumption-tier learning deployment. See README security section.
  #checkov:skip=CKV_AZURE_212:Consumption plans autoscale per-execution with no fixed worker_count concept; minimum-instance guarantees require Premium (min. 3 always-ready instances). Accepted for a Consumption-tier learning deployment. See README security section.
  name                = "${var.prefix}-plan"
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
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  tags = var.tags
}

resource "azuerm_storage_account_queue_properties" "queue_properties" {
  storage_account_id = azurerm_storage_account.function_runtime.id
  logging {
    delete                = true
    read                  = true
    write                 = true
    version               = "1.0"
    retention_policy_days = 7
  }
}

# Private endpoint is required, because public access is disabled, so the
# Function App (via its VNet integration) can still reach its own
# runtime storage for triggers/state.
resource "azurerm_private_endpoint" "function_runtime" {
  name                = "${var.prefix}-fnrt-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.virtual_network_subnet_id

  private_service_connection {
    name                           = "${var.prefix}-fnrt-psc"
    private_connection_resource_id = azurerm_storage_account.function_runtime.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.blob_private_dns_zone_id]
  }

  tags = var.tags
}

resource "azurerm_linux_function_app" "main" {
  #checkov:skip=CKV_AZURE_221:Disabling public access would break APIM's ability to reach the Function backend, since APIM stays on Consumption tier with no VNet integration. Accepted for a Consumption-tier deployment. See README security section.

  name                = "${var.prefix}-func"
  location            = var.location
  resource_group_name = var.resource_group_name

  https_only = true

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
    "FUNCTIONS_WORKER_RUNTIME"     = "python"
    "AZURE_CLIENT_ID"              = var.azure_function_client_id
    "KEY_VAULT_URI"                = var.key_vault_vault_uri
    "REPORTS_STORAGE_ACCOUNT_NAME" = var.reports_storage_account_name
    "SQL_CONNECTION_STRING_SECRET" = var.sql_connection_string_secret
    "ACS_CONNECTION_STRING_SECRET" = var.acs_connection_string_secret
    "ACS_SENDER_ADDRESS"           = "DoNotReply@${var.acs_from_sender_domain}"
  }

  tags = var.tags
}
