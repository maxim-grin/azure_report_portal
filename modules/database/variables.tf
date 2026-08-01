variable "prefix" {
  description = "Naming prefix, e.g. project-environment from the root module's locals"
  type        = string
}

variable "location" {
  type        = string
  description = "Azure location"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "sql_admin_login" {
  description = "Admin username for Azure SQL server"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "Admin password for Azure SQL server"
  type        = string
  sensitive   = true
}

variable "aad_object_id" {
  description = "AAD object id"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the storage account's private endpoint"
  type        = string
}

variable "sql_private_dns_zone_id" {
  type        = string
  description = "Private DNS zone ID for privatelink.database.windows.net"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
