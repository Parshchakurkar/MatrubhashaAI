output "VMName" {
  value = azurerm_linux_virtual_machine.matrubhashaai-vm.name
}
output "ResourceGroupName" {
  value = azurerm_resource_group.matrubhashaai-rg.name
}

output "Location" {
  value = azurerm_resource_group.matrubhashaai-rg.location
}