output "default_hostname" {
  description = "Function App hostname — the client's API base URL now that there is no gateway in front"
  value       = azurerm_linux_function_app.main.default_hostname
}

output "function_app_name" {
  value = azurerm_linux_function_app.main.name
}
