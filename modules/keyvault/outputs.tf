output "key_vault_id" {
  description = "Used by the root module to grant RBAC"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  value =  azurerm_key_vault.main.name
}

output "key_vault_vault_uri" {
  value =  azurerm_key_vault.main.vault_uri
}
output "sql_connection_string" {
  value =  azurerm_key_vault_secret.sql_connection_string.name
}
output "acs_connection_string" {
  value =  azurerm_key_vault_secret.acs_connection_string.name
}