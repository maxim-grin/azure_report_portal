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

variable "project" {
  description = "Project name, used in resource naming"
  type        = string
}

variable "admin_email" {
  description = "Email address for alerts and admin notifications"
  type        = string
}

variable tenant_id {
  type        = string
  description = "Azure tenant ID"
}

variable client_id {
  type        = string
  description = "Azure application client ID"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
