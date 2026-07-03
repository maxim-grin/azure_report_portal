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
  # See README "Getting started" step 2 for the az cli commands.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "yourstateaccount" # must be globally unique, set your own
    container_name        = "tfstate"
    key                    = "report-portal.terraform.tfstate"
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
