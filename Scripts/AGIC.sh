
RESOURCE_GROUP="matrubhashaAI"
IDENTITY_NAME="agic-identity"
# Sign in to your Azure subscription.
SUBSCRIPTION_ID='*****'

# Register required resource providers on Azure.
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network

AKS_NAME='<your cluster name>'
RESOURCE_GROUP='<your resource group name>'

az aks update -g $RESOURCE_GROUP -n $AKS_NAME --enable-oidc-issuer --enable-workload-identity --no-wait

AKS_NAME='<your cluster name>'
RESOURCE_GROUP='<your resource group name>'
LOCATION='northeurope'
VM_SIZE='<the size of the vm in AKS>' # The size needs to be available in your location

az group create --name $RESOURCE_GROUP --location $LOCATION
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_NAME \
    --location $LOCATION \
    --node-vm-size $VM_SIZE \
    --network-plugin azure \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --generate-ssh-key