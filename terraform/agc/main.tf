data "azurerm_kubernetes_cluster" "aks" {
  name                = "matrubhashaaicluster"
  resource_group_name = "matrubhashaai-rg"
}
data "azurerm_virtual_network" "vnet" {
  name = "matrubhashaai-vnet"
  resource_group_name = "matrubhashaai-rg"
}
data "azurerm_resource_group" "rg" {
  name = "matrubhashaai-rg"
}
data "azapi_client_config" "this" {}

# AG4C association subnet — delegated to Microsoft.ServiceNetworking/trafficControllers
resource "azapi_resource" "subnet_agc" {
  name      = "subnet-agc"
  parent_id = data.azurerm_virtual_network.vnet.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = {
      addressPrefix = "10.0.2.0/24"
      delegations = [{
        name = "agc-delegation"
        properties = {
          serviceName = "Microsoft.ServiceNetworking/trafficControllers"
        }
      }]
    }
  }
  # The Application Gateway for Containers association keeps the subnet briefly
  # "in use" after it is deleted; retry the subnet deletion until it is released.
  retry = {
    error_message_regex  = ["InUseSubnetCannotBeDeleted"]
    interval_seconds     = 30
    max_interval_seconds = 120
  }
}

#------------------------------------------------------------------------------
# AGC UAMI 
#------------------------------------------------------------------------------
resource "azapi_resource" "uami_alb" {
  location  = data.azurerm_kubernetes_cluster.aks.location
  name      = "id-alb-controller"
  parent_id = data.azurerm_resource_group.rg.id
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
}
resource "random_uuid" "role_agc_config_manager" {}

resource "random_uuid" "role_network_contributor" {}

resource "random_uuid" "ra_node_reader" {}
#------------------------------------------------------------------------------
# AGC UAMI role assignments
#------------------------------------------------------------------------------

# Role: AppGw for Containers Configuration Manager on the Resource Group
resource "azapi_resource" "role_agc_config_manager" {
  name      = random_uuid.role_agc_config_manager.result
  parent_id = data.azurerm_resource_group.rg.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = azapi_resource.uami_alb.output.properties.principalId
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/fbc52c3f-28ad-4303-a892-8a056630b8f1"
    }
  }
  response_export_values = []
}

# Role: Network Contributor on the AG4C subnet
resource "azapi_resource" "role_network_contributor" {
  name      = random_uuid.role_network_contributor.result
  parent_id = azapi_resource.subnet_agc.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = azapi_resource.uami_alb.output.properties.principalId
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7"
    }
  }
  response_export_values = []
}


# Reader on the AKS node resource group
data "azurerm_resource_group" "node_rg" {
  name = data.azurerm_kubernetes_cluster.aks.node_resource_group
}

resource "azapi_resource" "ra_node_reader" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.ra_node_reader.result
  parent_id = data.azurerm_resource_group.node_rg.id

  body = {
    properties = {
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      principalId      = azapi_resource.uami_alb.output.properties.principalId
      principalType    = "ServicePrincipal"
    }
  }
}

#------------------------------------------------------------------------------
# fedarated credential for AGC UAMI to access AKS
#------------------------------------------------------------------------------
resource "azapi_resource" "alb_fic" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31"
  name      = "alb-controller-fic"
  parent_id = azapi_resource.uami_alb.id

  body = {
    properties = {
      issuer    = "https://centralindia.oic.prod-aks.azure.com/08f340e4-237b-49ec-992e-f7ff501db9ef/cd24fee7-1fe3-4daf-b9c3-fbe7faa935b7/"
      subject   = "system:serviceaccount:azure-alb-system:alb-controller-sa"
      audiences = ["api://AzureADTokenExchange"]
    }
  }
}



# -----------------------------------------------------------------------------
# agc module
#------------------------------------------------------------------------------
module "agc" {
  source = "./terraform-azurerm-avm-res-servicenetworking-trafficcontroller-main"
  location  = data.azurerm_kubernetes_cluster.aks.location
  name      = "agc-for-aks"
  parent_id = data.azurerm_resource_group.rg.id
  associations = {
    main = {
      name               = "association-main"
      subnet_resource_id = azapi_resource.subnet_agc.id
    }
  }
  enable_telemetry = var.enable_telemetry
  frontends = {
    web = {
      name = "frontend-web"
    }
  }
}