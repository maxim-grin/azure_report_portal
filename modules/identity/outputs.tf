output "application_client_id" {
  description = "Azure application client id"
  value       = azuread_application.api.client_id
}

output "function_identity_id" {
  description = "Function identity id"
  value       = azurerm_user_assigned_identity.function.id
}

output "azure_function_client_id" {
  description = "Azure function client id"
  value       = azurerm_user_assigned_identity.function.client_id
}

output "function_principal_id" {
  description = "Function principal id"
  value       = azurerm_user_assigned_identity.function.principal_id
}
