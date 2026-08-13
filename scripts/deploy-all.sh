#!/bin/bash
set -e

echo "===== Start Assignment3 Full Deployment ====="

# 1. Install monitoring stack (Prometheus + Grafana) via Helm
echo "[1/4] Deploy kube-prometheus-stack monitoring stack"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/values.yaml

# 2. Deploy ArgoCD Application CR (GitOps sync entry)
echo "[2/4] Apply ArgoCD Application manifest"
kubectl apply -f gitops/argocd-app.yaml

echo "[3/4] Waiting for ArgoCD to sync resources (wait 30s)..."
sleep 30

# 3. Verify core workload status
echo "[4/4] Check running workload pods"
kubectl get pods

echo "===== Deployment Finished ====="
echo "Tips:"
echo "1. Open ArgoCD UI after port-forward"
echo "2. Confirm app status becomes Synced & Healthy"
echo "3. Configure Grafana and select datasource prometheus-1"
