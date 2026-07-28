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

  public_network_access_enabled = false

  azuread_administrator {
    login_username = "sql-aad-admin"
    object_id      = data.azurerm_client_config.current.object_id
  }

  tags = var.tags
}

resource "azurerm_mssql_database" "main" {
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

  tags = var.tags
}
