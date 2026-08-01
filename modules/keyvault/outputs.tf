output "key_vault_id" {
  description = "Used by the root module to grant RBAC"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}
