terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.69.0"
    }
  }
}

provider "azurerm" {
  features {

  }
}

resource "azurerm_resource_group" "teste" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "teste" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.teste.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "teste" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.teste.name
  virtual_network_name = azurerm_virtual_network.teste.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "teste" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.teste.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.teste.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "teste" {
  name                  = "${var.prefix}-vm"
  resource_group_name   = azurerm_resource_group.teste.name
  location              = var.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.teste.id]
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_ed25519.pub")
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}