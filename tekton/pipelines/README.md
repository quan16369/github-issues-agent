# Tekton CI/CD Pipelines

Complete CI/CD pipelines for the GitHub Issue Agent with automated builds, tests, security scans, and GitOps deployments.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Repository                            │
└───────────┬─────────────────────┬─────────────────────┬─────────┘
            │                     │                     │
     Push to dev           Merge to main         Create tag v*
            │                     │                     │
            ▼                     ▼                     ▼
   ┌─────────────────┐   ┌──────────────────┐  ┌──────────────────┐
   │  Dev Pipeline   │   │ Staging Pipeline │  │  Prod Pipeline   │
   └─────────────────┘   └──────────────────┘  └──────────────────┘
            │                     │                     │
     1. git-clone            1. git-clone          1. git-clone
     2. sonar-scan           2. run-tests          2. run-tests
     3. kaniko-build         3. sonar-scan         3. promote-image
     4. trivy-scan          4. kaniko-build       4. trivy-scan
     5. update-manifest      5. trivy-scan         5. tag-latest
            │                6. update-manifest    6. update-manifest
            ▼                     │                     │
   ┌─────────────────┐           ▼                     ▼
   │ Harbor Dev      │   ┌──────────────────┐  ┌──────────────────┐
   └─────────────────┘   │ Harbor Staging   │  │  Harbor Prod     │
            │             └──────────────────┘  └──────────────────┘
            ▼                     │                     │
   ┌─────────────────┐           ▼                     ▼
   │ k8s/overlays/   │   ┌──────────────────┐  ┌──────────────────┐
   │     dev         │   │ k8s/overlays/    │  │ k8s/overlays/    │
   └─────────────────┘   │   staging        │  │    prod          │
            │             └──────────────────┘  └──────────────────┘
            ▼                     │                     │
   ┌─────────────────┐           ▼                     ▼
   │ ArgoCD Auto     │   ┌──────────────────┐  ┌──────────────────┐
   │  Deploy Dev     │   │ ArgoCD Deploy    │  │ ArgoCD Deploy    │
   └─────────────────┘   │    Staging       │  │    Production    │
                          └──────────────────┘  └──────────────────┘
```

## Pipelines

### 1. Dev Pipeline (`dev-pipeline.yaml`)

**Trigger:** Push to `dev` branch

**Steps:**
1. **git-clone** - Clone repository at dev branch
2. **code-quality-scan** - Run SonarQube analysis
3. **build-image** - Build Docker image with Kaniko
4. **security-scan** - Scan with Trivy (non-blocking)
5. **update-manifest** - Update k8s/overlays/dev

**Image Tag:** `dev-<commit-sha>`

**Quality Gates:**
- SonarQube scan (informational)
- Trivy scan (non-blocking)

### 2. Staging Pipeline (`staging-pipeline.yaml`)

**Trigger:** Push/merge to `main` branch

**Steps:**
1. **git-clone** - Clone repository at main
2. **run-tests** - Execute unit and integration tests
3. **code-quality-scan** - SonarQube with quality gate
4. **build-image** - Build production-ready image
5. **security-scan** - Trivy scan (CRITICAL/HIGH fail)
6. **update-manifest** - Update k8s/overlays/staging

**Image Tag:** `staging-<commit-sha>`

**Quality Gates:**
- All tests must pass
- SonarQube quality gate must pass
- No CRITICAL/HIGH vulnerabilities

### 3. Production Pipeline (`prod-pipeline.yaml`)

**Trigger:** Create tag `v*` (e.g., v1.0.0)

**Steps:**
1. **git-clone** - Clone at specific tag
2. **run-tests** - Full test suite
3. **promote-image** - Copy staging image to prod
4. **security-scan** - Final Trivy scan
5. **tag-latest** - Tag as latest
6. **update-manifest** - Update k8s/overlays/prod

**Image Tag:** Tag name (e.g., `v1.0.0`) + `latest`

**Quality Gates:**
- All tests must pass
- Image must exist in staging
- No CRITICAL/HIGH vulnerabilities
- Manual approval (optional)

## Setup Instructions

### Prerequisites

1. **GKE cluster** with Tekton installed
2. **Harbor registry** configured
3. **SonarQube** server (optional)
4. **ArgoCD** for GitOps

### 1. Install Tekton Tasks

```bash
kubectl apply -f tekton/tasks/
```

### 2. Create Secrets

```bash
# Harbor credentials
kubectl create secret docker-registry harbor-credentials \
  --docker-server=harbor.example.com \
  --docker-username=robot$tekton \
  --docker-password=<robot-token> \
  -n tekton-pipelines

# Git credentials (for pushing manifest updates)
kubectl create secret generic git-credentials \
  --from-file=id_rsa=~/.ssh/id_rsa \
  --from-file=known_hosts=~/.ssh/known_hosts \
  -n tekton-pipelines

# GitHub webhook secret
kubectl create secret generic github-webhook-secret \
  --from-literal=secret=<your-webhook-secret> \
  -n tekton-pipelines

# SonarQube token (optional)
kubectl create secret generic sonarqube-token \
  --from-literal=token=<sonar-token> \
  -n tekton-pipelines
```

### 3. Create Service Account

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-triggers-sa
  namespace: tekton-pipelines
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tekton-triggers-role
  namespace: tekton-pipelines
rules:
  - apiGroups: ["tekton.dev"]
    resources: ["eventlisteners", "triggerbindings", "triggertemplates", "pipelineruns"]
    verbs: ["get", "list", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tekton-triggers-rolebinding
  namespace: tekton-pipelines
subjects:
  - kind: ServiceAccount
    name: tekton-triggers-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: tekton-triggers-role
EOF
```

### 4. Install Pipelines

```bash
kubectl apply -f tekton/pipelines/
```

### 5. Configure GitHub Webhooks

Get the EventListener URL:
```bash
kubectl get svc -n tekton-pipelines | grep listener
```

In GitHub repository settings:
1. Go to Settings → Webhooks → Add webhook
2. **Payload URL:** `http://<listener-url>:8080`
3. **Content type:** application/json
4. **Secret:** Your webhook secret
5. **Events:** Push, Create (for tags)

### 6. Expose EventListener (Optional)

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tekton-webhooks
  namespace: tekton-pipelines
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - tekton-webhooks.example.com
      secretName: tekton-webhooks-tls
  rules:
    - host: tekton-webhooks.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: el-dev-pipeline-listener
                port:
                  number: 8080
EOF
```

## Testing Pipelines

### Manually Trigger Dev Pipeline

```bash
tkn pipeline start dev-pipeline \
  -w name=shared-workspace,volumeClaimTemplateFile=workspace-pvc.yaml \
  -w name=docker-credentials,secret=harbor-credentials \
  -w name=git-credentials,secret=git-credentials \
  -p git-url=https://github.com/your-org/github-issue-agent.git \
  -p git-revision=dev \
  -p image-tag=dev-manual-test \
  --showlog
```

### Manually Trigger Staging Pipeline

```bash
tkn pipeline start staging-pipeline \
  -w name=shared-workspace,volumeClaimTemplateFile=workspace-pvc.yaml \
  -w name=docker-credentials,secret=harbor-credentials \
  -w name=git-credentials,secret=git-credentials \
  -p git-url=https://github.com/your-org/github-issue-agent.git \
  -p image-tag=staging-$(git rev-parse --short HEAD) \
  --showlog
```

### Manually Trigger Prod Pipeline

```bash
tkn pipeline start prod-pipeline \
  -w name=shared-workspace,volumeClaimTemplateFile=workspace-pvc.yaml \
  -w name=docker-credentials,secret=harbor-credentials \
  -w name=git-credentials,secret=git-credentials \
  -p git-url=https://github.com/your-org/github-issue-agent.git \
  -p git-tag=v1.0.0 \
  -p staging-image-tag=staging-abc123 \
  --showlog
```

## Monitoring Pipelines

### View Pipeline Runs

```bash
# List all runs
tkn pipelinerun list

# Watch a specific run
tkn pipelinerun logs <pipelinerun-name> -f

# Get run details
tkn pipelinerun describe <pipelinerun-name>
```

### View in Tekton Dashboard

```bash
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097
open http://localhost:9097
```

### View in Grafana

Import Tekton dashboard (ID: 12229) in Grafana.

## Workflow Examples

### Development Workflow

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Develop and test locally
# ...

# 3. Push to dev branch
git push origin feature/new-feature:dev

# 4. Pipeline automatically:
#    - Builds image
#    - Scans code
#    - Pushes to Harbor dev
#    - Updates dev manifest
#    - ArgoCD deploys to dev cluster
```

### Staging Deployment

```bash
# 1. Merge PR to main
git checkout main
git merge feature/new-feature
git push origin main

# 2. Pipeline automatically:
#    - Runs tests
#    - Builds image
#    - Security scan (strict)
#    - Pushes to Harbor staging
#    - Updates staging manifest
#    - ArgoCD deploys to staging
```

### Production Release

```bash
# 1. Create release tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 2. Pipeline automatically:
#    - Runs full tests
#    - Promotes staging image to prod
#    - Final security scan
#    - Updates prod manifest
#    - ArgoCD syncs production (manual/auto)
```

## Customization

### Adding Steps

Edit pipeline YAML and add new task:

```yaml
- name: custom-step
  taskRef:
    name: custom-task
  runAfter:
    - previous-step
  params:
    - name: param1
      value: value1
```

### Changing Quality Gates

In `trivy-scan` task params:
```yaml
- name: severity
  value: "CRITICAL"  # or "CRITICAL,HIGH,MEDIUM"
- name: exit-code
  value: "1"  # Fail pipeline, or "0" for informational
```

### Custom Notifications

Add notification task at the end:

```yaml
- name: notify-slack
  taskRef:
    name: send-to-webhook-slack
  when:
    - input: "$(tasks.status)"
      operator: in
      values: ["Failed", "Succeeded"]
  params:
    - name: webhook-url
      value: $(params.slack-webhook)
    - name: message
      value: "Pipeline $(context.pipelineRun.name) $(tasks.status)"
```

## Troubleshooting

### Pipeline Fails at Build

```bash
# Check task logs
tkn taskrun logs <taskrun-name>

# Check workspace
kubectl describe pvc <workspace-pvc>
```

### Can't Push to Harbor

```bash
# Verify credentials
kubectl get secret harbor-credentials -o yaml

# Test manually
docker login harbor.example.com
```

### Manifest Update Fails

```bash
# Check git credentials
kubectl get secret git-credentials -o yaml

# Verify SSH key has write access
```

### EventListener Not Receiving Webhooks

```bash
# Check service
kubectl get svc -n tekton-pipelines

# Check logs
kubectl logs -n tekton-pipelines -l eventlistener=dev-pipeline-listener
```

## Best Practices

1. **Use semantic versioning** for production tags (v1.0.0, v1.1.0)
2. **Always run tests** before deploying to staging/prod
3. **Use image digests** instead of tags for production
4. **Enable security scanning** with strict policies for prod
5. **Implement manual approval** for production deployments
6. **Monitor pipeline metrics** in Grafana
7. **Set up notifications** for pipeline failures
8. **Use separate Harbor projects** for each environment
9. **Keep pipeline definitions in Git** (GitOps for CI/CD)
10. **Document custom pipelines** for your team

## Resources

- [Tekton Documentation](https://tekton.dev/docs/)
- [Tekton Catalog](https://hub.tekton.dev/)
- [Harbor Documentation](https://goharbor.io/docs/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
