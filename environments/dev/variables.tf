variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westus2"
}

variable "project" {
  description = "Project name, used in resource naming"
  type        = string
  default     = "reportportal"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "admin_email" {
  description = "Email address for alerts and admin notifications"
  type        = string
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

variable "subscription_id" {
  description = "Azure subscription ID — required by the azurerm provider from v4.0 onward"
  type        = string
}
