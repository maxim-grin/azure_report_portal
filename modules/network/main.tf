resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  address_space       = ["10.0.0.0/16"]

  tags = var.tags
}

# Subnet for Function App (VNet integration, outbound to private endpoints)
resource "azurerm_subnet" "functions" {
  name                 = "snet-functions"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "function-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet for private endpoints (Key Vault, SQL)
resource "azurerm_subnet" "private" {
  name                 = "snet-private-endpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  private_endpoint_network_policies_enabled = true
}

resource "azurerm_network_security_group" "private" {
  name                = "${var.prefix}-private-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow the Function subnet to reach the private endpoints in this subnet (Key Vault: 443, Storage/blob: 443, SQL: 1433)
  security_rule {
    name                       = "AllowFunctionSubnetToPrivateEndpoints"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "1433"]
    source_address_prefix      = azurerm_subnet.functions.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}
