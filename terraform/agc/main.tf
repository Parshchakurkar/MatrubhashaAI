data "azapi_kubernetes_cluster" "aks" {
  name = "matrubhashaaicluster"
  resource_group_name = "matrubhashaai-rg"
}
data "azapi_resource" "vnet" {
  name = "matrubhashaai-vnet"
  type = "Microsoft.Network/virtualNetworks@2024-05-01"
}
data "azapi_resource" "rg" {
  name = "matrubhashaai-rg"
  type = "Microsoft.Resources/resourceGroups@2021-04-01"
}
data "azapi_client_config" "this" {}

# AG4C association subnet — delegated to Microsoft.ServiceNetworking/trafficControllers
resource "azapi_resource" "subnet_agc" {
  name      = "subnet-agc"
  parent_id = azapi_resource.vnet.id
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

resource "azapi_resource" "uami_alb" {
  location  = data.azapi_kubernetes_cluster.aks.location
  name      = "id-alb-controller"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
}
# Role: AppGw for Containers Configuration Manager on the Resource Group
resource "azapi_resource" "role_agc_config_manager" {
  name      = random_uuid.role_agc_config_manager.result
  parent_id = azapi_resource.rg.id
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


# -----------------------------------------------------------------------------
module "agc" {
  source = "terraform-azurerm-modules/application-gateway-for-containers/azurerm"
  location  = data.azapi_kubernetes_cluster.aks.location
  name      = "agc-for-aks"
  parent_id = azapi_resource.rg.id
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