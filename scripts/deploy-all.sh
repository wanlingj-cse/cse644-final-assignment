#!/bin/bash
set -e

echo "===== Start Assignment3 Full Deployment ====="

# 1. Install Prometheus & Grafana monitoring stack via Helm
echo "[1/5] Deploy kube-prometheus-stack monitoring stack"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/values.yaml

# 2. Install ArgoCD via official Helm Chart (fix CRD annotation too long error)
echo "[2/5] Install ArgoCD Controller via Helm"
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm install argocd argo/argo-cd -n argocd

echo "[3/5] Wait 90s for ArgoCD controller all pods ready..."
sleep 90

# 3. Create ArgoCD Application GitOps sync resource
echo "[4/5] Apply ArgoCD Application manifest"
kubectl apply -f gitops/argocd-app.yaml

echo "[5/5] Wait 30s for ArgoCD auto-sync GitHub manifests"
sleep 30

# Final workload check
echo "[6/6] List all running pods across all namespaces"
kubectl get pods -A

echo -e "\n===== Deployment Finished ====="
echo "Tips for accessing UIs:"
echo "1. ArgoCD UI port-forward command:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "2. Grafana datasource select any among these: prometheus-1, default, Prometheus"
echo "3. Retrieve Grafana admin password:"
echo "kubectl --namespace monitoring get secrets kube-prometheus-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d ; echo"
