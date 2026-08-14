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
Expected clean output on a fresh Minikube cluster (no workload deployed yet):
```bash
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   2d9h
```
Only the default Kubernetes service exists, confirming kubectl can successfully communicate with the Minikube control plane, and no leftover workloads exist from prior tests.
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
#### Open ArgoCD UI Step-by-Step Port Forward
1. Host machine terminal create SSH tunnel (must add -- before -L):
vagrant ssh -- -L 8080:127.0.0.1:8080
Keep this terminal open all the time.

2. Open a new host terminal to log into Vagrant VM:
vagrant ssh

3. Inside Vagrant, forward ArgoCD service port:
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443

4. Visit ArgoCD in host browser: http://localhost:8080

5. Retrieve default admin password inside Vagrant:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

6. In order to run argocd commands, we need to login first using user name admin, password is what we just got from step 5:
```bash
argocd login localhost:8080
```

To access Grafana and Prometheus monitoring dashboards, we also need to set up two-layer port-forward tunnels to open Prometheus and Grafana UI on host browser, how to port-forward is in section 5 of CSE644_HW3_WanlingJiang.pdf.

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
Run:
```bash
kubectl get pods -l app=nginx-health -w
```

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
2. Inside another Vagrant terminal tab, forward Grafana service port:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
```
3. Open host browser URL: http://localhost:3000

4. Default username is admin, get login password in another vagrant terminal tab:
```bash
kubectl --namespace monitoring get secret kube-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```
5. Download the dashboard json according to section 5 of CSE644_HW3_WanlingJiang.pdf, the json file is under this link: https://grafana.com/grafana/dashboards/12708-nginx/, then import the dashboard json to grafana and you will get the dashboard.

6. Then go to Dashboard Setting -> Variables, edit instance variable, let it be:
```bash
label_values(nginx_connections_active, instance)
```
And fill in Custom all value .+ 

Save and refresh page.

Note that if NGINX Status shows no data, we need to find the {} on the right hand side of the grafana page, and edit:
```bash
nginx_up{instance=~"$instance"}
```
Change it to:
```bash
nginx_up{instance=~"$instance"} OR nginx_up
```
#### Access Prometheus (Port 9090)
1.Host terminal persistent tunnel:
```bash
vagrant ssh -- -L 9090:127.0.0.1:9090
```
2. Vagrant terminal port-forward listening on all VM interfaces:
```bash
kubectl port-forward --address 0.0.0.0 -n monitoring prometheus-kube-prometheus-kube-prome-prometheus-0 9090:9090
```
3. Open host browser URL: http://localhost:9090

4. If in Promethus page, it says there's a time shift, run this:
```bash
sudo timedatectl set-ntp true
```

5. Then, we can query metrics like nginx_http_requests_total.

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

