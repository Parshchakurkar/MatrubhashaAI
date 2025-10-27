#!/bin/bash
# ============================================================
# Script Name: install-argocd.sh
# Purpose: Automate installation of Argo CD on a Kubernetes cluster
# Author: Prashant Chakurkar
# ============================================================

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail

# --- Step 1: Create namespace ---
echo "Creating namespace 'argocd'..."
kubectl create namespace argocd 2>/dev/null || echo "Namespace 'argocd' already exists."

# --- Step 2: Install Argo CD manifests ---
echo "Applying Argo CD manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# --- Step 3: Patch Argo CD server to use LoadBalancer ---
echo "Patching Argo CD server service to type LoadBalancer..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# --- Step 4: Display Argo CD service info ---
echo "Retrieving Argo CD service details..."
kubectl get svc -n argocd

# --- Step 5: Get Argo CD initial admin password ---
echo "Fetching Argo CD initial admin password..."
kubectl -n argocd get secret
ADMIN_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
echo "============================================================"
echo "Argo CD Initial Admin Password: $ADMIN_PASS"
echo "============================================================"
echo "Argo CD Initial User: admin"
echo "============================================================"


# --- Step 6: (Optional) Delete the admin secret for security ---
echo "🧹 Deleting the Argo CD admin secret (optional step)..."
kubectl delete secret argocd-initial-admin-secret -n argocd || echo "Secret already deleted."
echo ""
echo "------------------------------------------------------------"
echo "You can access Argo CD UI using the LoadBalancer external IP:"
echo "kubectl get svc -n argocd argocd-server"
echo ""
