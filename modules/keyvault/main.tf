resource "azurerm_key_vault" "main" {
  name                       = "${var.prefix}-kv"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = var.sku

  # RBAC authorization instead of legacy access policies — cleaner,
  # auditable, and managed the same way as the rest of Azure IAM.
  enable_rbac_authorization  = true
  purge_protection_enabled   = false
  # Soft delete + purge protection so secrets can't be permanently lost
  # (or maliciously purged) on a fat-finger delete.
  soft_delete_retention_days = 7

  public_network_access_enabled = false

  tags = local.common_tags
}

# Private endpoint — Key Vault unreachable from public internet
resource "azurerm_private_endpoint" "kv" {
  name                = "${local.prefix}-kv-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${local.prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  tags = local.common_tags
}

# Secrets
resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};Authentication=Active Directory Managed Identity;"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.terraform_kv_admin]
}

resource "azurerm_key_vault_secret" "acs_connection_string" {
  name         = "acs-connection-string"
  value        = azurerm_communication_service.main.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.terraform_kv_admin]
}
