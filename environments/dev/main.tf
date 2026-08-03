data "azurerm_client_config" "current" {}

locals {
  prefix = "${var.project}-${var.environment}"

  private_dns_zones = {
    blob  = "privatelink.blob.core.windows.net"
    vault = "privatelink.vaultcore.azure.net"
    sql   = "privatelink.database.windows.net"
  }

  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = azurerm_private_dns_zone.this
  resource_group_name   = azurerm_resource_group.main.name
  name                  = "${local.prefix}-${each.key}-link"
  private_dns_zone_name = each.value.name
  virtual_network_id    = module.network.vnet_id
  tags                  = local.common_tags
}

module "network" {
  source = "../../modules/network"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  blob_private_dns_zone_id = azurerm_private_dns_zone.this["blob"].id

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.private_subnet_id
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "function_storage_contributor" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.identity.function_principal_id
}

module "keyvault" {
  source = "../../modules/keyvault"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  subnet_id           = module.network.private_subnet_id
  tenant_id           = data.azurerm_client_config.current.tenant_id

  vault_private_dns_zone_id = azurerm_private_dns_zone.this["vault"].id

  tags = local.common_tags
}

# Terraform identity needs Key Vault Secrets Officer to write secrets in keyvault.tf
resource "azurerm_role_assignment" "terraform_kv_admin" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Function App identity reads secrets — read-only, not write
resource "azurerm_role_assignment" "function_kv_reader" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.identity.function_principal_id
}

resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${module.database.mssql_fully_qualified_domain_name},1433;Database=${module.database.mssql_database_name};Authentication=Active Directory Managed Identity;"
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"


  depends_on = [azurerm_role_assignment.terraform_kv_admin]
}

resource "azurerm_key_vault_secret" "acs_connection_string" {
  name         = "acs-connection-string"
  value        = module.communication.communication_primary_connection_string
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.terraform_kv_admin]
}

module "database" {
  source = "../../modules/database"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.prefix
  subnet_id           = module.network.private_subnet_id
  sql_admin_login     = var.sql_admin_login
  sql_admin_password  = var.sql_admin_password
  aad_object_id       = data.azurerm_client_config.current.object_id

  sql_private_dns_zone_id = azurerm_private_dns_zone.this["sql"].id

  tags = local.common_tags
}

# Function App identity reads payroll data from SQL — via AAD auth, no password
resource "azurerm_role_assignment" "function_sql_contributor" {
  scope                = module.database.mssql_server_id
  role_definition_name = "SQL DB Contributor"
  principal_id         = module.identity.function_principal_id
}

module "communication" {
  source = "../../modules/communication"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.prefix
  data_location       = "United States"

  tags = local.common_tags
}

# Function App identity sends email via ACS
resource "azurerm_role_assignment" "function_acs_sender" {
  scope                = module.communication.communication_service_id
  role_definition_name = "Contributor" # tighten in prod
  principal_id         = module.identity.function_principal_id
}

module "identity" {
  source = "../../modules/identity"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.prefix
  tags                = local.common_tags
}

module "functions" {
  source = "../../modules/functions"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  prefix                       = local.prefix
  virtual_network_subnet_id    = module.network.function_subnet_id
  identity_ids                 = [module.identity.function_identity_id]
  key_vault_vault_uri          = module.keyvault.key_vault_vault_uri
  sql_connection_string_secret = azurerm_key_vault_secret.sql_connection_string.name
  acs_connection_string_secret = azurerm_key_vault_secret.acs_connection_string.name
  azure_function_client_id     = module.identity.azure_function_client_id
  reports_storage_account_name = module.storage.storage_account_name
  acs_from_sender_domain       = module.communication.from_sender_domain
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  client_origin                = var.client_origin

  depends_on = [
    azurerm_role_assignment.function_kv_reader,
    azurerm_role_assignment.function_storage_contributor,
    azurerm_role_assignment.function_sql_contributor,
  ]

  blob_private_dns_zone_id = azurerm_private_dns_zone.this["blob"].id

  tags = local.common_tags
}
