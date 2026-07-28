output "function_subnet_id" {
  description = "Subnet id used to run functions"
  value       = azurerm_subnet.functions.id
}

output "private_subnet_id" {
  description = "Private subnet Id (used for Key Vault, Storage, DB)"
  value       = azurerm_subnet.private.id
}
