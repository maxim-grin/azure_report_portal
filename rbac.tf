# Terraform identity needs Key Vault Secrets Officer to write secrets in keyvault.tf
resource "azurerm_role_assignment" "terraform_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Function App identity reads secrets — read-only, not write
resource "azurerm_role_assignment" "function_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
}

# Function App identity reads/writes blobs (paystub PDFs)
resource "azurerm_role_assignment" "function_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
}

# Function App identity reads payroll data from SQL — via AAD auth, no password
resource "azurerm_role_assignment" "function_sql_contributor" {
  scope                = azurerm_mssql_server.main.id
  role_definition_name = "SQL DB Contributor"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
}

# Function App identity sends email via ACS
resource "azurerm_role_assignment" "function_acs_sender" {
  scope                = azurerm_communication_service.main.id
  role_definition_name = "Contributor" # tighten in prod — see note below
  principal_id         = azurerm_user_assigned_identity.function.principal_id
}
