# CSE644 Assignment 03 – GitOps & Application Observability
Student Name: Wanling Jiang

Email: wanling.jiang@cstu.edu

GitHub Username: wanlingj

Repository URL: https://github.com/wanlingj/cse644-final-assignment.git

Local K8s Environment: Vagrant + Minikube single-node cluster

GitOps Controller: ArgoCD

Monitoring Stack: kube-prometheus-stack (Prometheus Operator, Prometheus, Grafana)

Base Workload: All manifests inherited from Assignment 2; GitOps, monitoring, observability files newly added for Assignment3

## Repository Directory Tree
```bash
.
├── gitops
│   └── argocd-app.yaml               # ArgoCD Application CR to sync GitHub repo with cluster
├── manifests                         # Core K8s workload manifests migrated from Assignment 2
│   ├── app-secret.yaml
│   ├── deploy-healthcheck.yaml
│   ├── haproxy-deploy.yaml
│   ├── ingress.yaml
│   ├── nginx-configmap.yaml          # Nginx config with stub_status enabled for metrics
│   ├── nginx-deploy.yaml
│   ├── nginx-exporter-deploy.yaml
│   ├── nginx-exporter-svc.yaml
│   ├── nginx‑health‑nodeport.yaml
│   ├── nginx-servicemonitor.yaml
│   ├── nginx-web-sm.yaml
│   ├── podmonitor.yaml               # PodMonitor for auto-scraping nginx-exporter metrics
│   ├── public-demo.yaml
│   ├── pv-pvc.yaml
│   ├── python-deploy.yaml
│   ├── svc-clusterip.yaml
│   ├── svc-loadbalancer.yaml
│   ├── svc-nginx-web.yaml
│   └── svc-nodeport.yaml
├── monitoring
│   └── values.yaml                  # Helm custom values for deploying Prometheus & Grafana
├── scripts
│   ├── cleanup-all.sh               # One-click shell script to delete all assignment resources
│   └── deploy-all.sh                # One-click shell script for full stack deployment
└── README.md                        # Full assignment documentation
```
Total: 5 directories, 25 files. All base workload definitions reused from Assignment 2; gitops/, monitoring/, scripts/ and observability manifests are newly created to satisfy Assignment 3 GitOps & monitoring requirements.

## 1. Prerequisite Environment Configuration
### Vagrantfile Modification for Port Forwarding & Resource Allocation
To access ArgoCD, Prometheus and Grafana web UIs from the host machine, I updated the VirtualBox provider section inside Vagrantfile:
```bash
config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    config.vm.network "forwarded_port", guest: 8080, host: 8080  # ArgoCD UI port
    config.vm.network "forwarded_port", guest: 9090, host: 9090  # Prometheus UI port
end
```
vb.memory = "4096": Allocate sufficient memory to run Minikube, ArgoCD and monitoring stack without OOM crashes. This is a core environment setup optimization, not only for web page access.

Port forwarding rules expose guest VM internal ports to host browser for ArgoCD (8080) and Prometheus (9090).

### Verify Kubernetes Environment Works
Run basic validation command to confirm Minikube & kubectl connectivity:
```bash
kubectl get all -n default
```
## 2. One-Click Automated Deployment
All services can be deployed sequentially via the provided automation script scripts/deploy-all.sh without manually executing commands step by step.
```bash
chmod +x scripts/deploy-all.sh
./scripts/deploy-all.sh
```
### Script Execution Workflow
1. Update Helm repo and install kube-prometheus-stack monitoring stack using custom monitoring/values.yaml

2. Apply ArgoCD Application CR to start GitOps synchronization with GitHub manifest repo

3. Short wait period for ArgoCD to pull manifests and reconcile resources
   
4. Print all running Pods for quick health verification

After the whole script completes and ArgoCD finishes automatic sync, execute kubectl get all -n default to inspect workload state:

All core workloads including haproxy-edge, nginx-health, nginx-web, python-web are running normally with healthy replicas.

Evidence is in section 2 of CSE644_HW3_WanlingJiang.pdf.

### Important Post-Deployment Notes
To access monitoring dashboards, we need to set up two-layer port-forward tunnels to open Prometheus and Grafana UI on host browser, how to port-forward is in section 5 of CSE644_HW3_WanlingJiang.pdf.

## 3. GitOps Deployment via ArgoCD 
### Core Concept
The GitHub repository acts as the single source of desired cluster state. ArgoCD continuously syncs all manifests under ./manifests to Minikube cluster automatically. Any change committed to GitHub will be applied to the cluster without manual kubectl commands.

### Deployment Evidence (In section 2 of CSE644_HW3_WanlingJiang.pdf)
Access ArgoCD UI at http://localhost:8080. The application status shows Synced and all declared resources are fully provisioned.

## 4.Git-Driven State Change and Automatic Reconciliation (Evidence in section 3 of CSE644_HW3_WanlingJiang.pdf)
This section proves ArgoCD strictly enforces Git as the only source of truth for cluster configuration.
### 4.1 Git Change: Scale Nginx Replicas via Git Commit
1. Modify replica count inside manifests/deploy-healthcheck.yaml from 1 to 2

2. Commit and push changes to GitHub remote repo:
```bash
git add manifests/deploy-healthcheck.yaml
git commit -m "Scale nginx-health replicas to 2 for GitOps reconciliation test"
git push origin main
```
3. ArgoCD detects the Git state drift and automatically rolls out updated Deployment

4. Observation: The second Pod transitions through lifecycle Pending → ContainerCreating → Running and finally reaches 1/1 Ready status.

### 4.2 Live Cluster Drift and Auto Reconciliation
Simulate unsanctioned manual cluster modification (direct kubectl change outside Git):
```bash
kubectl scale deployment nginx-health --replicas=1
```
After manual scaling down, ArgoCD detects mismatch between live cluster state and Git declared state, marks app as OutOfSync temporarily

ArgoCD reconciliation loop automatically restores replica count back to 2 defined in GitHub manifest

Key takeaway: All manual out-of-Git modifications will be overwritten to align with Git desired state.

## 5. Controlled Deployment Failure & Git-Based Full Recovery
I intentionally inject a broken configuration via Git to simulate production deployment failure, diagnose issues using ArgoCD & Kubernetes native tools, then fully recover by fixing code in Git only (no direct kubectl hotfixes on cluster).
### 5.1 Introduce Failure Through Git Commit
Edit manifests/deploy-healthcheck.yaml to use an invalid non-existent container image tag:
```bash
image: wanlingj/cse644-custom-nginx:invalid-broken-tag
```
Commit faulty manifest and push to GitHub remote repository:
```bash
git commit -m "Inject invalid image tag to simulate controlled deployment failure"
git push origin main
```
### 5.2 Evidence
All evidences and explanations are in section 4 of CSE644_HW3_WanlingJiang.pdf.

## 6. Application Observability: Prometheus & Grafana Full Stack
### 6.1 Port Forward Workflow to Access Monitoring UIs
The environment uses double-layer virtualization (Host → Vagrant VM → Minikube), requiring two layers of port forwarding to open Prometheus/Grafana on host browser.
#### Access Grafana (Port 3000)
1. Run host terminal tunnel to forward port into Vagrant VM:
```bash
vagrant ssh -- -L 3000:127.0.0.1:3000
```
2. Inside Vagrant terminal, forward Grafana service port:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
3. Open host browser URL: http://localhost:3000
#### Access Prometheus (Port 9090)
1.Host terminal persistent tunnel:
```bash
vagrant ssh -- -L 9090:127.0.0.1:9090
```
2. Vagrant terminal port-forward listening on all VM interfaces:
```bash
kubectl port-forward --address 0.0.0.0 svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
```
3. Open host browser URL: http://localhost:9090
### 6.2 Evidences 
All Evidences and explanations are in section 5 of CSE644_HW3_WanlingJiang.pdf.
### 6.3 Grafana Data Source Important Configuration
When opening Grafana Connections → Data sources, multiple Prometheus entries exist:
I created a new one prometheus-1, but it turns out using any of the 3 data sources works.

## 7. Resource Cleanup Operation
One-click automated cleanup script:
```bash
chmod +x scripts/cleanup-all.sh
./scripts/cleanup-all.sh
```
### Script Workflow Explanation
1. Delete ArgoCD Application CR to trigger cascading deletion of GitOps managed resources

2. Uninstall Prometheus Helm release and delete entire monitoring namespace

3. Manually delete all manifests under manifests/ to clear leftover workload resources

4. Remove full argocd namespace to erase GitOps controller completely

5. Final print of cluster resources for user verification of cleanup result

