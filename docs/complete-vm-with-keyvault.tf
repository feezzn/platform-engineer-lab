# # complete-vm-with-keyvault.tf
# # Este arquivo mostra um exemplo COMPLETO de VM com Key Vault e Disk Encryption
# # Use como referência para estudar a ordem de recursos e como eles se conectam

# terraform {
#   required_version = ">= 1.0"
#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~> 4.0"
#     }
#   }
# }

# provider "azurerm" {
#   features {
#     key_vault {
#       purge_soft_delete_on_destroy       = false
#       purge_soft_deleted_keys_on_destroy = false
#     }
#   }
# }

# # ====== DATA SOURCES ======
# # Ler informações do Azure sem criar nada de novo

# data "azurerm_client_config" "current" {}

# # ====== VARIABLES ======

# variable "prefix" {
#   type    = string
#   default = "platformlab"
# }

# variable "location" {
#   type    = string
#   default = "eastus"
# }

# # ====== RESOURCE GROUP ======

# resource "azurerm_resource_group" "test" {
#   name     = "${var.prefix}-resources"
#   location = var.location
# }

# # ====== NETWORKING ======

# resource "azurerm_virtual_network" "test" {
#   name                = "${var.prefix}-network"
#   address_space       = ["10.0.0.0/16"]
#   location            = azurerm_resource_group.test.location
#   resource_group_name = azurerm_resource_group.test.name
# }

# resource "azurerm_subnet" "test" {
#   name                 = "internal"
#   resource_group_name  = azurerm_resource_group.test.name
#   virtual_network_name = azurerm_virtual_network.test.name
#   address_prefixes     = ["10.0.2.0/24"]
# }

# resource "azurerm_network_interface" "test" {
#   name                = "${var.prefix}-nic"
#   resource_group_name = azurerm_resource_group.test.name
#   location            = azurerm_resource_group.test.location

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.test.id
#     private_ip_address_allocation = "Dynamic"
#   }
# }

# # ====== KEY VAULT ======

# resource "azurerm_key_vault" "test" {
#   name                        = "${var.prefix}kv${substr(data.azurerm_client_config.current.client_id, 0, 8)}"
#   location                    = azurerm_resource_group.test.location
#   resource_group_name         = azurerm_resource_group.test.name
#   tenant_id                   = data.azurerm_client_config.current.tenant_id
#   sku_name                    = "premium"
#   enabled_for_disk_encryption = true
#   purge_protection_enabled    = true
# }

# # ====== KEY VAULT ACCESS POLICY ======
# # Este é um requisito: você precisa de permissão pra criar chaves no KV

# resource "azurerm_key_vault_access_policy" "service_principal" {
#   key_vault_id = azurerm_key_vault.test.id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = data.azurerm_client_config.current.object_id

#   key_permissions = [
#     "Create",
#     "Delete",
#     "Get",
#     "Update",
#   ]

#   secret_permissions = [
#     "Get",
#     "Delete",
#     "Set",
#   ]
# }

# # ====== KEY VAULT KEY ======
# # Depende da access policy estar criada

# resource "azurerm_key_vault_key" "test" {
#   name         = "examplekey"
#   key_vault_id = azurerm_key_vault.test.id
#   key_type     = "RSA"
#   key_size     = 2048

#   key_opts = [
#     "decrypt",
#     "encrypt",
#     "sign",
#     "unwrapKey",
#     "verify",
#     "wrapKey",
#   ]

#   depends_on = [
#     azurerm_key_vault_access_policy.service_principal
#   ]
# }

# # ====== LINUX VIRTUAL MACHINE ======

# resource "azurerm_linux_virtual_machine" "test" {
#   name                = "${var.prefix}-vm"
#   resource_group_name = azurerm_resource_group.test.name
#   location            = azurerm_resource_group.test.location
#   size                = "Standard_D2s_v3"

#   disable_password_authentication = true
#   admin_username                  = "adminuser"

#   network_interface_ids = [
#     azurerm_network_interface.test.id,
#   ]

#   admin_ssh_key {
#     username   = "adminuser"
#     public_key = file("~/.ssh/id_rsa.pub")
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "0001-com-ubuntu-server-jammy"
#     sku       = "22_04-lts"
#     version   = "latest"
#   }
# }

# # ====== VM EXTENSION: DISK ENCRYPTION ======
# # Executa um script na VM pra criptografar o disco

# resource "azurerm_virtual_machine_extension" "disk_encryption" {
#   name                       = "AzureDiskEncryptionForLinux"
#   publisher                  = "Microsoft.Azure.Security"
#   type                       = "AzureDiskEncryptionForLinux"
#   type_handler_version       = "1.1"
#   auto_upgrade_minor_version = false
#   virtual_machine_id         = azurerm_linux_virtual_machine.test.id

#   settings = jsonencode({
#     EncryptionOperation    = "EnableEncryption"
#     KeyEncryptionAlgorithm = "RSA-OAEP"
#     KeyVaultURL            = azurerm_key_vault.test.vault_uri
#     KeyVaultResourceId     = azurerm_key_vault.test.id
#     KeyEncryptionKeyURL    = azurerm_key_vault_key.test.id
#     KekVaultResourceId     = azurerm_key_vault.test.id
#     VolumeType             = "All"
#   })
# }

# # ====== OUTPUTS ======

# output "vm_id" {
#   value       = azurerm_linux_virtual_machine.test.id
#   description = "ID da VM"
# }

# output "vm_private_ip" {
#   value       = azurerm_linux_virtual_machine.test.private_ip_address
#   description = "IP privado da VM"
# }

# output "key_vault_id" {
#   value       = azurerm_key_vault.test.id
#   description = "ID do Key Vault"
# }

# output "key_vault_uri" {
#   value       = azurerm_key_vault.test.vault_uri
#   description = "URI do Key Vault"
# }
