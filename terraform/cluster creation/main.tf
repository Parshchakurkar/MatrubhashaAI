data "azurerm_resource_group" "matrubhashaai_rg" {
  name = "matrubhashaai-rg"
}

resource "azurerm_virtual_network" "matrubhashaai_vnet" {
  name                = "matrubhashaai-vnet"
  location            = data.azurerm_resource_group.matrubhashaai_rg.location
  resource_group_name = data.azurerm_resource_group.matrubhashaai_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "matrubhasha_subnet" {
  name                 = "matrubhasha-subnet"
  resource_group_name  = data.azurerm_resource_group.matrubhashaai_rg.name
  virtual_network_name = azurerm_virtual_network.matrubhashaai_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_kubernetes_cluster" "matrubhashaai_cluster" {
  name                = "matrubhashaaicluster"
  location            = data.azurerm_resource_group.matrubhashaai_rg.location
  resource_group_name = data.azurerm_resource_group.matrubhashaai_rg.name
  dns_prefix          = "matrubhashaaicluster-dns"
  # Enable RBAC for the Kubernetes Cluster
  role_based_access_control_enabled = true

  default_node_pool {
    name           = "default"
    vm_size        = "standard_D2ds_v6"
    node_count     = 1
    zones          = ["1"]
    vnet_subnet_id = azurerm_subnet.matrubhasha_subnet.id
  }
  identity {
    type = "SystemAssigned"
  }
  network_profile {
    network_plugin = "azure"
    service_cidr = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
    network_policy = "azure"
  }

}

resource "azurerm_container_registry" "matrubhashaai_acr" {
  name                = "matrubhashaaiacr"
  location            = data.azurerm_resource_group.matrubhashaai_rg.location
  resource_group_name = data.azurerm_resource_group.matrubhashaai_rg.name
  sku                 = "Basic"
  admin_enabled       = "false"

}

resource "azurerm_role_assignment" "aksacr" {
  principal_id         = azurerm_kubernetes_cluster.matrubhashaai_cluster.kubelet_identity[0].object_id
  scope                = azurerm_container_registry.matrubhashaai_acr.id
  role_definition_name = "AcrPull"
}