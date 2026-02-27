# Configure the Terraform runtime requirements.
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    # Azure Resource Manager provider and version
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }
  }
}

# Define providers and their config params
provider "azurerm" {
  # Leave the features block empty to accept all defaults
  features {}
}

provider "cloudinit" {
  # Configuration options
}

# define the rg using the variables we defined
resource "azurerm_resource_group" "main" {
  name     = "${var.labelPrefix}-A05-RG"
  location = var.region
}

# define the public ip
resource "azurerm_public_ip" "vm_pip" {
  name                = "${var.labelPrefix}-A05-PIP"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name

  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

# define the vnet in range 10.0.0.0/16
resource "azurerm_virtual_network" "main_vnet" {
  name                = "${var.labelPrefix}-A05-VNET"
  address_space = ["10.0.0.0/16"]
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
}

# define the subnet w range 10.0.1.0/24
resource "azurerm_subnet" "main_subnet" {
  name                 = "${var.labelPrefix}-A05-SUBNET"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name

  address_prefixes = ["10.0.1.0/24"]
}

# define nsgs for ssh and http
resource "azurerm_network_security_group" "main_nsg" {
  name                = "${var.labelPrefix}-A05-NSG"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
