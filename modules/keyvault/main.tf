resource "azurerm_key_vault" "main" {
  name                       = "${var.prefix}-kv"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = var.sku

  # RBAC authorization instead of legacy access policies — cleaner,
  # auditable, and managed the same way as the rest of Azure IAM.
  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  # Soft delete + purge protection so secrets can't be permanently lost
  # (or maliciously purged) on a fat-finger delete.
  soft_delete_retention_days = 7

  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Private endpoint — Key Vault unreachable from public internet
resource "azurerm_private_endpoint" "kv" {
  name                = "${var.prefix}-kv-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.vault_private_dns_zone_id]
  }

  tags = var.tags
}
