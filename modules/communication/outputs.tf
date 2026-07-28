output "communication_service_id" {
  description = "Used by the root module to grant RBAC"
  value       = azurerm_communication_service.main.id
}
