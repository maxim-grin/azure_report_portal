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

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID"
}

variable "sku" {
  type        = string
  description = "standard or premium"
  default     = "standard"
}

variable "subnet_id" {
  description = "Subnet ID for the storage account's private endpoint"
  type        = string
}

variable "vault_private_dns_zone_id" {
  type        = string
  description = "Private DNS zone ID for privatelink.vaultcore.azure.net"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
