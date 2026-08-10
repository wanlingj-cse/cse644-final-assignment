#!/bin/bash
set -euo pipefail
echo "=== 1. Delete Assignment3 ArgoCD Application ==="
kubectl delete -f ./gitops/argocd-app.yaml --ignore-not-found

echo "=== 2. Uninstall Prometheus & Grafana monitoring stack ==="
helm uninstall prometheus -n monitoring --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found

echo "=== 3. Delete all Assignment3 Kubernetes manifests ==="
kubectl delete -f ./manifests/ --ignore-not-found

echo "=== 4. Remove ArgoCD full namespace ==="
kubectl delete namespace argocd --ignore-not-found

echo "=== Cleanup finished, list remaining cluster resources ==="
kubectl get all
