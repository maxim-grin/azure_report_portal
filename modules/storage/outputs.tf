output "storage_account_id" {
  description = "Used by the root module to grant RBAC (e.g. Storage Blob Data Contributor to the Function's identity)"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  description = "Used to build the Function App's app settings (blob endpoint for report uploads)"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "reports_container_name" {
  value = azurerm_storage_container.reports.name
}
