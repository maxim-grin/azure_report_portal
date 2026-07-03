output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "api_client_id" {
  value = azuread_application.api.client_id
}
