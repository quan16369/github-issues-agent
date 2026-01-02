# Tekton Tasks

Core reusable tasks for CI/CD pipelines.

## Available Tasks

### Build & Push
- **kaniko-build** - Build and push Docker images using Kaniko (rootless, secure)
  - Supports multi-stage builds, build args, caching
  - Push to Harbor or GCR

- **push-to-harbor** - Push existing image to Harbor registry
  - Tag and push to multiple repositories
  - Harbor-specific authentication

### Code Quality & Security
- **sonar-scanner** - SonarQube code quality and security analysis
  - Static code analysis
  - Code coverage, bugs, vulnerabilities
  - Technical debt tracking

- **trivy-scan** - Container image vulnerability scanning
  - CVE detection in OS packages and application dependencies
  - High/Critical severity filtering
  - Fail pipeline on critical issues

- **run-tests** - Execute unit and integration tests
  - Python pytest
  - Test coverage reporting
  - JUnit XML output

### Source Control
- **git-clone** - Clone Git repository
  - Support for branches, tags, commits
  - SSH/HTTPS authentication
  - Submodule support

- **update-manifest** - Update Helm values with new image tag
  - GitOps workflow
  - Automatic commit and push
  - ArgoCD trigger

## Usage

All tasks are namespace-scoped to `tekton-pipelines`.

Example:
```yaml
tasks:
  - name: build-and-scan
    taskRef:
      name: kaniko-build
    workspaces:
      - name: source
        workspace: shared-workspace
    params:
      - name: image
        value: harbor.example.com/agent/app:v1.0.0
```

## Prerequisites

### Secrets Required
- `harbor-credentials` - Harbor registry authentication
- `sonarqube-token` - SonarQube API token
- `git-ssh-credentials` - Git SSH key for manifest updates (optional)

### ServiceAccounts
- `tekton-pipeline-sa` - With permissions to:
  - Read/write to workspaces
  - Pull/push to container registries
  - Update ConfigMaps/Secrets

## Task Dependencies

```
git-clone
    ↓
sonar-scanner (optional)
    ↓
kaniko-build
    ↓
trivy-scan
    ↓
push-to-harbor (if using Harbor)
    ↓
update-manifest
```

## Best Practices

1. **Use runAfter** - Control task execution order
2. **Share workspaces** - Avoid re-cloning repos
3. **Cache builds** - Enable Kaniko cache for faster builds
4. **Fail fast** - Run tests/scans before expensive builds
5. **Secrets** - Use Kubernetes secrets, never hardcode
6. **Labels** - Add metadata labels to images (git-commit, build-time)

## Customization

Tasks can be customized via:
- **Parameters** - Override defaults
- **Workspaces** - Mount different PVCs
- **Steps** - Add/remove steps via TaskRun
