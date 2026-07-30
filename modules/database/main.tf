resource "random_string" "sql_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_mssql_server" "main" {
  name                         = "${var.prefix}-sql-${random_string.sql_suffix.result}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

  minimum_tls_version = "1.2" 

  public_network_access_enabled = false

  azuread_administrator {
    login_username = "sql-aad-admin"
    object_id      = var.aad_object_id
  }

  tags = var.tags
}

resource "azurerm_mssql_database" "main" {
  #checkov:skip=CKV_AZURE_224:Ledger requires GRS/ZRS digest storage (current storage module uses LRS) and makes tables append-only, needing app-level schema review. Accepted for a learning deployment. See README security section.
  #checkov:skip=CKV_AZURE_229:Zone redundancy isn't available on General Purpose serverless and requires Premium/Business Critical/Hyperscale, which reintroduces the always-on cost this deployment avoids. Accepted for a learning deployment. See README security section.

  name        = "${var.prefix}-db"
  server_id   = azurerm_mssql_server.main.id
  sku_name    = "GP_S_Gen5_1" # General Purpose, Serverless, 1 vCore
  min_capacity = 0.5
  max_size_gb = 2

  auto_pause_delay_in_minutes = 60

  tags = var.tags
}

# Private endpoint — SQL unreachable from public internet
resource "azurerm_private_endpoint" "sql" {
  name                = "${var.prefix}-sql-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-sql-psc"
    private_connection_resource_id = azurerm_mssql_server.main.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.sql_private_dns_zone_id]
  }

  tags = var.tags
}
