variable "prefix" {
  description = "Naming prefix, e.g. \"${var.project}-${var.environment}\" from the root module's locals"
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

variable tentant_id {
  type        = string
  description = "Entra ID tenant ID"
}

variable sku {
    type = string
    description = "standard or premium"
    default = "standard"
}

variable "subnet_id" {
  description = "Subnet ID for the storage account's private endpoint"
  type        = string
}
