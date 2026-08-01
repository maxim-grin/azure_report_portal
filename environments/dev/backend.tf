terraform {
  # Backend blocks can't reference variables — Terraform needs to know
  # where state lives before it's loaded any .tf files or variables — so
  # the actual values live in a separate, gitignored backend.hcl file.
  backend "azurerm" {}
}