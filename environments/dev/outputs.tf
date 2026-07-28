output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "reports_container_name" {
  value = module.storage.reports_container_name
}

output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "api_client_id" {
  value = azuread_application.api.client_id
}
