# MatrubhashaAI
its an AI Application on a provider of blog link it will translate blog in the selected language
# Project HLD:
CI:
<img width="1186" height="604" alt="Screenshot 2025-09-11 at 5 17 39 PM" src="https://github.com/user-attachments/assets/77204d09-3d45-4677-97b5-89062dca9889" />


## Prerequisite:
1. Resource group with name matrubhashaai-rg in central india
2. Storage account with name 'matrubhashaai'
3. container with name of terraform
4. Service connection to resource manger with name matrubhashaai_project
5. Service connection with below access on storage account:
  - Storage Blob Data Contributor
  - Storage Queue Data Contributor

## Pipeline
### Build pipeline:
- In case of any changes in sources folder build pipeline will run.
- Build pipeline has stages as below
    - build
    - scan with snyk (OSS and code)
    - docker build
    - docker image scan with snyk
    - publish

### Infrastructure
  - After above prequisite done, trigger the pipeline
  - .tfstate file will be stored in storage account
  - Before apply the chnages there is manual approval so that changes will get reviewed before actual apply in azure

## Dockerfile:
It is created inside the source location.
- run ```Docker build -t matrubhashaai:1.0.0 .``` command in source location

## Terraform:
- Terraform used to create the private/ Self hosted agent in linux machine.
- Creating the AKS and ACR using terraform
- using snyk to scan the IAC files

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
    - Architecture:
<img width="1235" height="595" alt="Screenshot 2025-09-11 at 2 28 13 PM" src="https://github.com/user-attachments/assets/9ca02e94-442d-40ad-8d58-96374577b4fa" />
