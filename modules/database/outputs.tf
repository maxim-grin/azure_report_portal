output "mssql_server_id" {
  description = "Used by the root module to grant RBAC"
  value       = azurerm_mssql_server.main.id
}

output "mssql_database_name" {
  value = azurerm_mssql_database.main.name
}

output "mssql_fully_qualified_domain_name" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}
