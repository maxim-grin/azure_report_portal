variable "prefix" {
  description = "Naming prefix, e.g. project-environment from the root module's locals"
  type        = string
}

variable location {
  type        = string
  description = "Azure location"
}

variable resource_group_name {
    type = string
    description = "Name of the resource group"
}

variable "virtual_network_subnet_id" {
  description = "Subnet ID for the function runtime"
  type        = string
}

variable "identity_ids" {
  description = "Identity Ids"
  type        = list(string)
  default     = {}
}

variable "key_vault_vault_uri" {
  description = "Key Vault vault uri"
  type        = string
}

variable "sql_connection_string_secret" {
  description = "sql connection string"
  type        = string
}

variable "acs_connection_string_secret" {
  description = "acs connection string"
  type        = string
}

variable "azure_function_client_id" {
  description = "Azure function client id"
  type        = string
}

variable "reports_storage_account_name" {
  type        = string
  description = "Reports storage account name"
}

variable "acs_from_sender_domain" {
  type        = string
  description = "Email from sender domain"
}

variable "blob_private_dns_zone_id" {
  type        = string
  description = "Private DNS zone ID for privatelink.blob.core.windows.net"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
