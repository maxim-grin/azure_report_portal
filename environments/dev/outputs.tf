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
  value = module.identity.application_client_id
}

output "function_base_url" {
  description = "API base URL for client/config.js"
  value       = "https://${module.functions.default_hostname}/api"
}
