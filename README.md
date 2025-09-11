# MatrubhashaAI
its an AI Application on a provider of blog link it will translate blog in the selected language
# Project HLD:
<img width="894" height="351" alt="Screenshot 2025-08-26 at 12 30 19 AM" src="https://github.com/user-attachments/assets/aa6d7cf2-d2d5-45a8-8d8b-0cc71e59b4c2" />



## Prerequisite:
1. Resource group with name matrubhashaai-rg in central india
2. Storage account with name 'matrubhashaai'
3. container with name of terraform
4. Service connection to resource manger with name matrubhashaai_project
5. Service connection with below access on storage account:
  - Storage Blob Data Contributor
  - Storage Queue Data Contributor

## Dockerfile:
It is created inside the source location.
- run ```Docker build -t matrubhashaai:1.0.0 .``` command in source location

## Terraform:
- Terraform used to create the private/ Self hosted agent in linux machine.
- 

## Kubernetes:
- Deployment of the application in cluster.
- Created Public ip for ingress
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