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

variable data_location {
    type = string
    description = "Location of the data"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
