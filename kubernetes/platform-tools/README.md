# Platform Tools Installation Guide

This directory contains installation scripts for all platform tools required to run the GitHub Issue Agent on GKE.

## Prerequisites

1. **GKE Cluster** deployed via Terraform (see `iac/terraform/`)
2. **kubectl** configured to access your cluster
3. **Helm 3** installed
4. **Domain names** configured (or use LoadBalancer IPs)

## Quick Start

```bash
# Install all tools in one go
cd kubernetes/platform-tools
chmod +x *.sh
./install-all.sh
```

## Individual Installation

### 1. Nginx Ingress Controller
```bash
./install-nginx-ingress.sh
```
- Installs ingress controller with LoadBalancer
- Enables metrics and autoscaling
- Configures for GKE environment

### 2. Cert Manager
```bash
./install-cert-manager.sh
```
- Installs Cert Manager for SSL automation
- Creates ClusterIssuers for Let's Encrypt
- Update email in ClusterIssuers after installation

### 3. Harbor Container Registry
```bash
./install-harbor.sh harbor.yourdomain.com
```
- Installs Harbor with Trivy scanner
- Creates persistent storage
- Generates admin credentials
- **After installation**: Create projects (agent-dev, agent-staging, agent-prod)

### 4. Tekton CI/CD
```bash
./install-tekton.sh
```
- Installs Tekton Pipelines, Triggers, and Dashboard
- Applies project-specific tasks and pipelines
- Creates ingress for dashboard access

### 5. ArgoCD GitOps
```bash
./install-argocd.sh
```
- Installs ArgoCD for continuous delivery
- Creates ingress for web UI
- Generates admin credentials
- **After installation**: Configure applications and sync policies

### 6. Observability Stack
```bash
./install-observability.sh
```
- Installs Prometheus & Grafana (kube-prometheus-stack)
- Installs Jaeger for distributed tracing
- Installs OpenTelemetry Collector
- Configures exporters and pipelines

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Internet                             │
└─────────────────────┬───────────────────────────────────┘
                      │
              ┌───────▼────────┐
              │  LoadBalancer  │
              │  (Nginx)       │
              └───────┬────────┘
                      │
         ┌────────────┼────────────┐
         │            │            │
    ┌────▼───┐   ┌───▼────┐  ┌───▼────┐
    │ Harbor │   │ ArgoCD │  │Grafana │
    │Registry│   │ GitOps │  │Monitor │
    └────┬───┘   └───┬────┘  └───┬────┘
         │           │           │
    ┌────▼───────────▼───────────▼────┐
    │         GKE Cluster              │
    │  ┌──────────┐  ┌─────────────┐  │
    │  │ Tekton   │  │Application  │  │
    │  │ CI/CD    │  │ Workloads   │  │
    │  └──────────┘  └─────────────┘  │
    │  ┌──────────┐  ┌─────────────┐  │
    │  │Prometheus│  │ Jaeger      │  │
    │  │ Metrics  │  │ Tracing     │  │
    │  └──────────┘  └─────────────┘  │
    └──────────────────────────────────┘
                      │
              ┌───────▼────────┐
              │  Cloud SQL     │
              │  (PostgreSQL)  │
              └────────────────┘
```

## DNS Configuration

After installation, configure DNS A records:

```
harbor.yourdomain.com     -> <LoadBalancer-IP>
argocd.yourdomain.com     -> <LoadBalancer-IP>
grafana.yourdomain.com    -> <LoadBalancer-IP>
tekton.yourdomain.com     -> <LoadBalancer-IP>
jaeger.yourdomain.com     -> <LoadBalancer-IP>
github-agent.yourdomain.com -> <LoadBalancer-IP>
```

Get LoadBalancer IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## Post-Installation Configuration

### Harbor
1. Login to Harbor UI
2. Create projects:
   - `agent-dev` (public or private)
   - `agent-staging` (private)
   - `agent-prod` (private)
3. Create robot accounts for CI/CD
4. Enable Trivy scanning on push

### ArgoCD
1. Login to ArgoCD UI
2. Change default admin password
3. Connect GitHub repository
4. Create applications for each environment:
   ```bash
   argocd app create github-agent-dev \
     --repo https://github.com/your-org/github-issue-agent \
     --path kubernetes/manifests/overlays/dev \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace github-agent-dev
   ```

### Tekton
1. Create secrets for Harbor credentials:
   ```bash
   kubectl create secret docker-registry harbor-credentials \
     --docker-server=harbor.yourdomain.com \
     --docker-username=robot$account \
     --docker-password=<token> \
     -n tekton-pipelines
   ```

2. Create secrets for GitHub:
   ```bash
   kubectl create secret generic github-credentials \
     --from-literal=token=<your-github-token> \
     -n tekton-pipelines
   ```

### Grafana
1. Login to Grafana
2. Import dashboards:
   - Kubernetes Cluster Monitoring (ID: 7249)
   - Node Exporter Full (ID: 1860)
   - Tekton Dashboard (ID: 12229)
3. Configure alerts

### Cert Manager
Update email addresses for Let's Encrypt:
```bash
kubectl edit clusterissuer letsencrypt-staging
kubectl edit clusterissuer letsencrypt-prod
```

## Verification

### Check all pods are running
```bash
kubectl get pods -A | grep -E "ingress-nginx|cert-manager|harbor|tekton|argocd|monitoring|tracing"
```

### Check ingresses
```bash
kubectl get ingress -A
```

### Check certificates
```bash
kubectl get certificates -A
```

### Test services
```bash
# Nginx Ingress
curl -k https://harbor.yourdomain.com

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443
open https://localhost:8080

# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
open http://localhost:3000

# Tekton Dashboard
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097
open http://localhost:9097
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Certificate issues
```bash
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>
kubectl get certificaterequests -A
```

### Ingress issues
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Harbor not accessible
```bash
kubectl get pods -n harbor
kubectl logs -n harbor <harbor-core-pod>
```

## Uninstallation

To remove individual components:
```bash
helm uninstall <release-name> -n <namespace>
kubectl delete namespace <namespace>
```

To remove everything:
```bash
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall jaeger -n tracing
helm uninstall opentelemetry-collector -n monitoring
kubectl delete -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml
kubectl delete -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
helm uninstall harbor -n harbor
helm uninstall cert-manager -n cert-manager
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace monitoring tracing argocd tekton-pipelines harbor cert-manager ingress-nginx
```

## Cost Optimization

1. Use **preemptible nodes** for non-production environments
2. Enable **cluster autoscaling**
3. Set up **resource quotas** per namespace
4. Use **PodDisruptionBudgets** for critical services
5. Configure **HPA** (Horizontal Pod Autoscaling) for all services

## Security Best Practices

1. Change all default passwords immediately
2. Enable RBAC in all tools
3. Use **Network Policies** to restrict pod communication
4. Enable **PodSecurityPolicies** or **PodSecurityStandards**
5. Regularly update all tools to latest versions
6. Enable audit logging in GKE
7. Use **Workload Identity** for GCP service authentication

## Maintenance

### Update Helm releases
```bash
helm repo update
helm upgrade <release> <chart> -n <namespace>
```

### Backup critical data
```bash
# Harbor registry data
kubectl get pvc -n harbor

# Grafana dashboards
kubectl get configmap -n monitoring

# ArgoCD applications
kubectl get applications -n argocd -o yaml > argocd-backup.yaml
```

## Resources

- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Cert Manager](https://cert-manager.io/)
- [Harbor](https://goharbor.io/)
- [Tekton](https://tekton.dev/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)
- [Jaeger](https://www.jaegertracing.io/)
- [OpenTelemetry](https://opentelemetry.io/)
