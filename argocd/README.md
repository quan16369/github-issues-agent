# ArgoCD Applications

GitOps deployment configuration for all environments using ArgoCD.

## Architecture

```
GitHub Repository (main branch)
    │
    └─── k8s/overlays/
         ├── dev/          → ArgoCD → Dev Cluster (auto-sync)
         ├── staging/      → ArgoCD → Staging Cluster (auto-sync)
         └── prod/         → ArgoCD → Prod Cluster (manual sync)
```

## Applications

### 1. Dev Application (`dev-application.yaml`)

**Configuration:**
- **Namespace:** `default`
- **Auto-Sync:** Enabled
- **Self-Heal:** Enabled
- **Prune:** Enabled
- **Source:** `k8s/overlays/dev`

**Behavior:**
- Automatically syncs on every commit to `main`
- Self-heals if manual changes detected
- Prunes resources removed from Git

### 2. Staging Application (`staging-application.yaml`)

**Configuration:**
- **Namespace:** `staging`
- **Auto-Sync:** Enabled
- **Self-Heal:** Enabled
- **Prune:** Enabled
- **Source:** `k8s/overlays/staging`

**Behavior:**
- Same as dev but deployed to staging namespace
- Triggered after successful dev deployment

### 3. Production Application (`prod-application.yaml`)

**Configuration:**
- **Namespace:** `production`
- **Auto-Sync:** Manual (recommended)
- **Self-Heal:** Enabled
- **Prune:** Disabled (safety)
- **Source:** `k8s/overlays/prod`
- **Project:** `production` (restricted)

**Behavior:**
- Requires manual sync approval
- Self-heals drift after sync
- Does not automatically prune resources
- Optional sync windows (off-hours deployment)
- Slack notifications on sync/health changes

### 4. Application Set (`applicationset.yaml`)

Alternative approach using ApplicationSet to generate all three applications from a single manifest.

**Benefits:**
- Single source of truth
- Consistent configuration
- Easy to add new environments

## Installation

### Prerequisites

ArgoCD must be installed on your cluster:
```bash
kubectl apply -f kubernetes/platform-tools/install-argocd.sh
```

### 1. Create Production Project (Optional)

```bash
kubectl apply -f argocd/production-project.yaml
```

This creates a restricted project for production with:
- Limited allowed resources
- RBAC policies
- Sync windows

### 2. Deploy Applications

**Option A: Individual Applications**
```bash
# Deploy all environments
kubectl apply -f argocd/dev-application.yaml
kubectl apply -f argocd/staging-application.yaml
kubectl apply -f argocd/prod-application.yaml
```

**Option B: ApplicationSet (Recommended)**
```bash
# Deploy single ApplicationSet that generates all three
kubectl apply -f argocd/applicationset.yaml
```

### 3. Update Repository URL

Edit application files and replace:
```yaml
repoURL: https://github.com/your-org/github-issue-agent.git
```

With your actual repository URL.

### 4. Verify Applications

```bash
# List applications
kubectl get applications -n argocd

# Check application status
argocd app list

# Get detailed info
argocd app get github-agent-dev
```

## Configuration

### Auto-Sync vs Manual Sync

**Auto-Sync (Dev/Staging):**
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Manual Sync (Production):**
```yaml
syncPolicy:
  automated: null  # Omit automated section
```

### Sync Options

```yaml
syncOptions:
  - CreateNamespace=true        # Create namespace if missing
  - PrunePropagationPolicy=foreground  # Wait for resource deletion
  - PruneLast=true              # Prune after all other resources synced
```

### Ignore Differences

Ignore HPA-managed replica count:
```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas
```

### Sync Windows

Restrict production deployments:
```yaml
syncWindows:
  - kind: deny
    schedule: '0 9-17 * * 1-5'  # Deny 9AM-5PM Mon-Fri
    duration: 8h
  - kind: allow
    schedule: '0 0-8,18-23 * * *'  # Allow off-hours
    duration: 10h
```

## Workflows

### Development Workflow

```bash
# 1. Push code to dev branch
git push origin feature-branch:dev

# 2. Tekton pipeline runs:
#    - Build image
#    - Push to Harbor dev
#    - Update k8s/overlays/dev/kustomization.yaml with new image tag

# 3. ArgoCD detects change and auto-syncs
#    - Deploys to dev namespace
#    - Health checks pass

# 4. Verify in ArgoCD UI
argocd app get github-agent-dev
```

### Staging Deployment

```bash
# 1. Merge to main
git checkout main
git merge feature-branch
git push origin main

# 2. Tekton staging pipeline runs:
#    - Tests pass
#    - Build image
#    - Security scan
#    - Push to Harbor staging
#    - Update k8s/overlays/staging/

# 3. ArgoCD auto-syncs to staging
argocd app sync github-agent-staging
```

### Production Deployment

```bash
# 1. Create release tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 2. Tekton production pipeline:
#    - Tests pass
#    - Promote staging image to prod
#    - Update k8s/overlays/prod/

# 3. Manual sync in ArgoCD
argocd app sync github-agent-prod

# Or via UI:
# - ArgoCD UI → Applications → github-agent-prod
# - Click "SYNC"
# - Review changes
# - Confirm sync

# 4. Monitor deployment
argocd app wait github-agent-prod --health
```

## Monitoring

### ArgoCD UI

```bash
# Port-forward ArgoCD server
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access UI
open https://localhost:8080
# Username: admin
# Password: <from above>
```

### CLI Commands

```bash
# Install ArgoCD CLI
brew install argocd  # macOS
# or download from https://github.com/argoproj/argo-cd/releases

# Login
argocd login localhost:8080

# List applications
argocd app list

# Get application details
argocd app get github-agent-prod

# View sync status
argocd app sync github-agent-prod

# View application history
argocd app history github-agent-prod

# Rollback to previous version
argocd app rollback github-agent-prod 5

# View logs
argocd app logs github-agent-prod
```

### Health Checks

ArgoCD monitors:
- **Deployment:** Desired replicas = Available replicas
- **Service:** Endpoints exist
- **Ingress:** Valid configuration
- **HPA:** Within min/max bounds

### Sync Waves

Control deployment order with annotations:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy first
```

Example order:
1. Wave 0: ConfigMaps, Secrets
2. Wave 1: ServiceAccount
3. Wave 2: Deployment
4. Wave 3: Service
5. Wave 4: Ingress

## Notifications

### Slack Integration

Configure ArgoCD notifications:

```bash
# Install notifications controller (if not already)
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/release-1.0/manifests/install.yaml

# Configure Slack
kubectl create secret generic argocd-notifications-secret \
  -n argocd \
  --from-literal=slack-token=<YOUR_SLACK_BOT_TOKEN>

# Update configmap
kubectl patch cm argocd-notifications-cm -n argocd --patch '
data:
  service.slack: |
    token: $slack-token
  template.app-sync-succeeded: |
    message: Application {{.app.metadata.name}} synced successfully
  trigger.on-sync-succeeded: |
    - send: [app-sync-succeeded]
'
```

Add annotation to production app:
```yaml
annotations:
  notifications.argoproj.io/subscribe.on-sync-succeeded.slack: prod-deployments
```

## Troubleshooting

### Application OutOfSync

```bash
# Check differences
argocd app diff github-agent-prod

# Force sync
argocd app sync github-agent-prod --force
```

### Sync Fails

```bash
# View sync result
argocd app get github-agent-prod

# Check events
kubectl get events -n production

# View ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Health Degraded

```bash
# Check pod status
kubectl get pods -n production

# Describe deployment
kubectl describe deployment github-agent -n production

# View application logs
kubectl logs -n production -l app=github-agent --tail=100
```

### Manual Intervention Needed

```bash
# Delete application (keeps resources)
argocd app delete github-agent-dev --cascade=false

# Recreate application
kubectl apply -f argocd/dev-application.yaml
```

## Best Practices

1. **Use Separate Namespaces** - dev/staging/production
2. **Manual Sync for Production** - Require approval
3. **Enable Self-Heal** - Auto-correct drift
4. **Ignore HPA Replicas** - Prevent sync loops
5. **Use Sync Waves** - Control deployment order
6. **Set Retry Limits** - Avoid infinite loops
7. **Configure Notifications** - Stay informed
8. **Use Projects** - RBAC and policies
9. **Regular Backups** - Velero for cluster backups
10. **Monitor Sync Status** - Prometheus metrics

## Rollback

### Via ArgoCD

```bash
# View history
argocd app history github-agent-prod

# Rollback to revision
argocd app rollback github-agent-prod 5
```

### Via Git

```bash
# Revert commit
git revert <commit-sha>
git push origin main

# ArgoCD will sync the revert
```

## Security

### RBAC

Production project limits access:
```yaml
roles:
  - name: admin
    policies:
      - p, proj:production:admin, applications, *, production/*, allow
    groups:
      - sre-team
```

### Secrets Management

Use Sealed Secrets or External Secrets:
```bash
# Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml
```

Then reference SealedSecret instead of Secret in manifests.

## Metrics

ArgoCD exposes Prometheus metrics:
```promql
# Applications out of sync
argocd_app_info{sync_status="OutOfSync"}

# Sync failures
rate(argocd_app_sync_total{phase="Failed"}[5m])

# Health degraded
argocd_app_info{health_status!="Healthy"}
```

## Next Steps

1. ArgoCD Applications created
2. Setup Sealed Secrets for sensitive data
3. Add ArgoCD dashboards to Grafana
4. Configure sync failure alerts
5. Write deployment runbooks
6. Test disaster recovery procedures

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ApplicationSet Documentation](https://argocd-applicationset.readthedocs.io/)
- [ArgoCD Notifications](https://argocd-notifications.readthedocs.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
