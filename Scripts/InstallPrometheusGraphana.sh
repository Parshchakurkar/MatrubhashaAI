#!/bin/bash
# ============================================================
# Script Name: install-prometheus-grafana.sh
# Purpose: Automate Prometheus + Grafana installation via Helm
# Author: Prashant Chakurkar
# ============================================================

set -e  # Exit on error
set -o pipefail

# --- Step 1: Add Prometheus Helm repo ---
echo "Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# --- Step 2: Update Helm repos ---
echo "Updating Helm repositories..."
helm repo update

# --- Step 3: List Helm repos ---
echo "Helm repositories list:"
helm repo list

# --- Step 4: Create namespace ---
echo "Creating namespace 'prometheus'..."
kubectl create namespace prometheus 2>/dev/null || echo "Namespace 'prometheus' already exists."

# --- Step 5: Install kube-prometheus-stack ---
echo "Installing kube-prometheus-stack Helm chart..."
helm install prometheus prometheus-community/kube-prometheus-stack -n prometheus

# --- Step 6: Verify resources ---
echo "Getting all Prometheus resources..."
kubectl get all -n prometheus

# --- Step 7: Get Grafana admin credentials ---
echo "🔑 Retrieving Grafana credentials..."

ADMIN_USER=$(kubectl get secret -n prometheus prometheus-grafana -o=jsonpath='{.data.admin-user}' | base64 -d)
ADMIN_PASS=$(kubectl get secret -n prometheus prometheus-grafana -o=jsonpath='{.data.admin-password}' | base64 -d)

echo ""
echo "============================================================"
echo "✅ Grafana Admin User: $ADMIN_USER"
echo "✅ Grafana Admin Password: $ADMIN_PASS"
echo "============================================================"
echo ""

# --- Step 8: Display Prometheus port-forward instructions ---
echo ""
echo "To access Prometheus UI locally, run in a separate terminal:"
echo "kubectl port-forward -n prometheus prometheus-prometheus-kube-prometheus-prometheus-0 9090"
echo "Then open http://localhost:9090"
echo ""

# --- Step 9: Show Grafana port-forward command ---
echo "To access Grafana UI locally, run in a separate terminal:"
echo "kubectl port-forward -n prometheus svc/prometheus-grafana 3000:80"
echo "Then open http://localhost:3000"
echo ""

# --- Step 10: Done ---
echo "🎉 Prometheus + Grafana installation completed successfully!"
