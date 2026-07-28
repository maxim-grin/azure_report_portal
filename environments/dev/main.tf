data "azurerm_client_config" "current" {}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state — created manually before first `terraform init`.
  # Key is per-environment so dev/staging/prod don't collide in the same
  # state container.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "yourstateaccount" # must be globally unique, set your own
    container_name       = "tfstate"
    key                  = "report-portal-dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}
provider "random" {}

locals {
  prefix = "${var.project}-${var.environment}"

  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "../../modules/network"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.private_subnet_id
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "function_storage_contributor" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.identity.function_principal_id
}

module keyvault {
    source = "../../modules/keyvault"

    prefix              = local.prefix
    resource_group_name = azurerm_resource_group.main.name
    location = var.location
    subnet_id           = module.network.private_subnet_id
    tenant_id = data.azurerm_client_config.current.tenant_id
    tags = local.tags
}

# Terraform identity needs Key Vault Secrets Officer to write secrets in keyvault.tf
resource "azurerm_role_assignment" "terraform_kv_admin" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Function App identity reads secrets — read-only, not write
resource "azurerm_role_assignment" "function_kv_reader" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.identity.function_principal_id
}

module database {
    source = "../../modules/database"

    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    prefix              = local.prefix
    subnet_id           = module.network.private_subnet_id
    sql_admin_login = var.sql_admin_login
    sql_admin_password = var.sql_admin_password

    tags = local.tags
}

# Function App identity reads payroll data from SQL — via AAD auth, no password
resource "azurerm_role_assignment" "function_sql_contributor" {
  scope                = module.database.mssql_server_id
  role_definition_name = "SQL DB Contributor"
  principal_id         = module.identity.function_principal_id
}

module communication {
    source = "../../modules/communication"

    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    prefix              = local.prefix
    data_location        = "United States"

    tags = local.tags
}

# Function App identity sends email via ACS
resource "azurerm_role_assignment" "function_acs_sender" {
  scope                = module.communication.communication_service_id
  role_definition_name = "Contributor" # tighten in prod
  principal_id         = module.identity.function_principal_id
}

module identity {
    source = "../../modules/identity"

    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    prefix              = local.prefix

    tags = local.tags
}

module apim {
    source = "../../modules/apim"

    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    tentant_id = data.azurerm_client_config.current.tenant_id
    client_id = module.identity.application_client_id
    prefix              = local.prefix
    project = var.project
    admin_email = var.admin_email
  
    tags = local.tags
}

module functions {
    source = "../../modules/functions"

    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    prefix              = local.prefix
    virtual_network_subnet_id = module.network.function_subnet_id
    identity_ids = [module.identity.function_identity_id]
    key_vault_vault_uri = module.keyvault.key_vault_vault_uri
    sql_connection_string = module.keyvault.sql_connection_string
    acs_connection_string = module.keyvault.acs_connection_string

    tags = local.tags
}

