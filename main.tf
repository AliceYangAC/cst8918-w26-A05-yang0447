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
  name     = "${var.labelPrefix}-A05-rg"
  location = var.region
}

# define the public ip
resource "azurerm_public_ip" "vm_pip" {
  name                = "${var.labelPrefix}-A05-pip"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name

  allocation_method = "Static"
  sku               = "Standard"
}

# define the vnet in range 10.0.0.0/16
resource "azurerm_virtual_network" "main_vnet" {
  name                = "${var.labelPrefix}-A05-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
}

# define the subnet w range 10.0.1.0/24
resource "azurerm_subnet" "main_subnet" {
  name                 = "${var.labelPrefix}-A05-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# define nsgs for ssh and http
resource "azurerm_network_security_group" "main_nsg" {
  name                = "${var.labelPrefix}-A05-nsg"
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

# define nic & associate w pip and subnet
resource "azurerm_network_interface" "main_nic" {
  name                = "${var.labelPrefix}-A05-nic"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip.id
  }
}

# associate nsg w nic
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.main_nic.id
  network_security_group_id = azurerm_network_security_group.main_nsg.id
}

data "cloudinit_config" "apache_init" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "init.sh"
    content_type = "text/x-shellscript"

    content = file("${path.module}/init.sh")
  }
}

# define latest ubuntu linux vm
resource "azurerm_linux_virtual_machine" "web_vm" {
  name                = "${var.labelPrefix}-A05-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.region
  size                = "Standard_B1s"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.main_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    name                 = "${var.labelPrefix}-A05-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(data.cloudinit_config.apache_init.rendered)
}

# output the resource group name
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

# output the public ip address of the vm
output "public_ip_address" {
  value = azurerm_public_ip.vm_pip.ip_address
}
