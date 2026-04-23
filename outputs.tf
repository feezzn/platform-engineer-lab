output "resource_group_name" {
  value = azurerm_resource_group.teste.name
}

output "vnet_id" {
  value = azurerm_virtual_network.teste.id
}

output "subnet_id" {
  value = azurerm_subnet.teste.id
}