output "communication_service_id" {
  description = "Used by the root module to grant RBAC"
  value       = azurerm_communication_service.main.id
}

output "communication_primary_connection_string" {
  value = azurerm_communication_service.main.primary_connection_string
}

output "from_sender_domain" {
  value = azurerm_email_communication_service_domain.main.from_sender_domain
}
