data "azurerm_resource_group" "matrubhashaai-rg" {
  name     = "matrubhashaai-rg"
}

resource "azurerm_kubernetes_cluster" "matrubhashaaicluster" {
  name                = "matrubhashaaicluster"
  location            = data.azurerm_resource_group.matrubhashaai-rg.location
  resource_group_name = data.azurerm_resource_group.matrubhashaai-rg.name
  dns_prefix          = "matrubhashaaicluster-dns"
  default_node_pool {
    name       = "default"
    vm_size    = "standard_D2ds_v6"
    node_count = 1
    zones = [ "1" ]
  }
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_container_registry" "matrubhashaaiacr" {
  name                = "matrubhashaaiacr"
  location            = data.azurerm_resource_group.matrubhashaai-rg.location
  resource_group_name = data.azurerm_resource_group.matrubhashaai-rg.name
  sku                 = "Basic"
  admin_enabled       = "false"

}