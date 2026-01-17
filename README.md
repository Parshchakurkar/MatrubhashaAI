
# MatrubhashaAI

**MatrubhashaAI** is an AI-driven web application that translates blog content into user-selected languages.  
The project demonstrates a complete **DevOps lifecycle** including CI/CD, Infrastructure as Code, Containerization, Observability, and GitOps using Azure and Kubernetes.

# Project HLD:
<img width="2406" height="1374" alt="image" src="https://github.com/user-attachments/assets/fb36513c-83d2-4735-8049-bc6ed6937694" />


## Prerequisite:
1. Resource group with name matrubhashaai-rg in central india
2. Storage account with name 'matrubhashaai'
3. container with name of terraform
4. Service connection to resource manger with name matrubhashaai_project
5. Service connection with below access on storage account:
  - Storage Blob Data Contributor
  - Storage Queue Data Contributor
  - User Access Administrator role for Service account so that it can assign ACRPULL role to ACR and AKS

## Azure CLI Commands to create resources (to setup things fast)
1. `az login` login to console and select required subscription
2. `az group create --name matrubhashaai-rg --location centralindia` - create resource group
3. `az storage account create --name matrubhashaai --resource-group matrubhashaai-rg  --location centralindia --sku Standard_LRS` - create storage account
4. `az storage container create --name terraform --account-name matrubhashaai` - create container

## Pipeline
### Build pipeline:
- In case of any changes in `/sources` folder build pipeline will run.
- Build pipeline has stages as below
    - build
    - scan with snyk (OSS and code)
    - docker build
    - docker image scan with snyk
    - publish

### Infrastructure as code
  - After above prequisite done, trigger the pipeline
  - .tfstate file will be stored in storage account
  - Manual approval gate before terraform apply for controlled deployment.

## Dockerfile:
It is created inside the source location.
- run ```Docker build -t matrubhashaai:1.0.0 .``` command in source location if want to create in local.
- Build pipeline will create and push image to acr.

## Terraform:
- Terraform used to create the private/ Self hosted agent in linux machine.
- Creating the AKS and ACR using terraform
- using snyk to scan the IAC files

# Helm package creation
- use `helm create matrubhashaai ` and remove not required files and copy kubernetes files in template folder.
- update chart and values file, use values in k8s files inside template.
- run command `helm install matrubhashaai matrubhashaai` - run this inside helm folder.
- check helm package ` helm lint matrubhashaai`
- package `helm package matrubhashaai`
-  ACR login `az acr login --name matrubhaaiacr`
- to push `helm push matrubhashaai-0.1.0.tgz oci://matrubhashaaiacr.azurecr.io/helm`


## Kubernetes:
- Deployment of the application in cluster.
- Created Public ip for ingress, Assign this ip to agentpool resourcegroup
- followed below steps:
    -  Create a namespace for your ingress resources
        kubectl create namespace ingress-basic

    -  Add the official stable repository
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo add stable https://charts.helm.sh/stable
      helm repo update
    - Used Helm to deploy an NGINX ingress controller
    - Used [valid kube tool](https://validkube.com/) to validate and scan k8s manifest
    - created a private IP in node pool resource grop, and assigned it to the nginx service(installed using helm)
    - Architecture:
<img width="1235" height="595" alt="Screenshot 2025-09-11 at 2 28 13 PM" src="https://github.com/user-attachments/assets/9ca02e94-442d-40ad-8d58-96374577b4fa" />

## observibility
### Prometheus and grafana
- run InstallPrometheusGraphana.sh it will create prometheus and grafana services
- use port forwording as mentioned in the script output and access portal
- Access the local ports and start making changes.

# Implemented gitOps concept
## ArgoCD
- Use InstallArgoCD.sh script to run argocd, run it agter `az aks get-credential` command
- login with user Admin and password you got from first password
- add/ create repo with ACR , use type oci and repo path `oci://matrubhashaaiacr.azurecr.io/helm/matrubhashaai`
- get password of ACR `az acr credentials show -n matrubhashaaiacr`
- provide user and password you will get out put from the above command.
- Once done create app. Provide app name and details with repo path and head to version of the file, and create.


# AGIC (Azure gateway ingress controller)
## Prerequisites
- AKS cluster and Application Gateway must be in the same VNet (or peered VNet) and AGW must have its own subnet.
- Create a user-assigned managed identity (or a service principal) that AGIC will use.
- Grant that identity permission to the Application Gateway (e.g., Contributor or at least Network Contributor on the AGW resource or AGW resource group).
- Your Kubernetes Service targeted by the Ingress should be ClusterIP (AGIC routes directly to pods/services).
## Create identity & role assignment (example)

- Create identity:
`az identity create -g <appgw-resource-group> -n agic-identity`
- Note the clientId and id (resourceId) from the output.
- Assign role on the Application Gateway resource (replace placeholders):
`az role assignment create --assignee <CLIENT_ID> --role "Contributor" --scope /subscriptions/<SUB>/resourceGroups/<AGW_RG>/providers/Microsoft.Network/applicationGateways/<APPGW_NAME>`
## Install AGIC via Helm (example)
