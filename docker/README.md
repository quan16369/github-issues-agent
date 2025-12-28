# Dockerfile Comparison Guide

This directory contains multiple Dockerfile variants optimized for different use cases.

## Available Dockerfiles

### 1. prod.Dockerfile (Original)
**Base Image:** `ghcr.io/astral-sh/uv:bookworm-slim`
**Purpose:** Original production build with UV package manager
**Size:** ~500-800MB
**Security:** Good
**Use Case:** Current production deployment

**Features:**
- UV package manager for fast installs
- Multi-stage build
- Guardrails integration
- NLTK data caching

### 2. prod-optimized.Dockerfile (Recommended)
**Base Image:** `python:3.11-slim-bookworm`
**Purpose:** Optimized production build with security hardening
**Size:** ~300-400MB
**Security:** Excellent
**Use Case:** Production deployments requiring balance of features and security

**Features:**
- Non-root user (appuser:1000)
- Minimal runtime dependencies
- Health checks built-in
- Clean separation of build and runtime
- Proper file permissions
- Smaller image size

**Improvements over original:**
- 40-50% smaller image size
- Runs as non-root user
- Only essential runtime packages
- Better layer caching
- Built-in health check

### 3. prod-distroless.Dockerfile (Most Secure)
**Base Image:** `gcr.io/distroless/python3-debian12:nonroot`
**Purpose:** Maximum security with minimal attack surface
**Size:** ~150-250MB
**Security:** Maximum
**Use Case:** High-security production deployments

**Features:**
- No shell (can't exec into container)
- No package manager
- Non-root by default
- Minimal attack surface
- Smallest image size

**Tradeoffs:**
- No debugging tools (no shell)
- Harder to troubleshoot
- Requires external monitoring

## Comparison Table

| Feature | Original | Optimized | Distroless |
|---------|----------|-----------|------------|
| Image Size | ~600MB | ~350MB | ~200MB |
| Security | Good | Excellent | Maximum |
| Shell Access | Yes | Yes | No |
| Debug Tools | Yes | Limited | No |
| Non-root User | No | Yes | Yes |
| Health Check | No | Yes | Limited |
| Maintenance | Easy | Easy | Advanced |
| Scan Vulnerabilities | ~20-50 | ~10-20 | ~0-5 |

## Recommendations by Environment

### Development
```dockerfile
# Use dev.Dockerfile (not shown)
# Includes debugging tools, hot-reload, etc.
```

### Staging
```dockerfile
# Use prod-optimized.Dockerfile
docker build -f docker/prod-optimized.Dockerfile -t app:staging .
```

### Production (Standard)
```dockerfile
# Use prod-optimized.Dockerfile
docker build -f docker/prod-optimized.Dockerfile -t app:prod .
```

### Production (High Security)
```dockerfile
# Use prod-distroless.Dockerfile
docker build -f docker/prod-distroless.Dockerfile -t app:prod-secure .
```

## Building Images

### Build Optimized Image
```bash
docker build -f docker/prod-optimized.Dockerfile \
  -t github-agent:latest \
  --target runtime \
  .
```

### Build Distroless Image
```bash
docker build -f docker/prod-distroless.Dockerfile \
  -t github-agent:distroless \
  .
```

### Build with BuildKit (faster)
```bash
DOCKER_BUILDKIT=1 docker build \
  -f docker/prod-optimized.Dockerfile \
  -t github-agent:latest \
  .
```

## Security Scanning

### Scan with Trivy
```bash
# Scan optimized image
trivy image github-agent:latest

# Scan distroless image
trivy image github-agent:distroless
```

### Scan with Grype
```bash
grype github-agent:latest
```

### Scan with Docker Scout
```bash
docker scout cves github-agent:latest
```

## Size Comparison

```bash
# Compare image sizes
docker images | grep github-agent

REPOSITORY      TAG          SIZE
github-agent    original     612MB
github-agent    optimized    342MB
github-agent    distroless   187MB
```

## Migration Path

### Step 1: Test Optimized Image
```bash
# Build optimized image
docker build -f docker/prod-optimized.Dockerfile -t github-agent:test .

# Run tests
docker run --rm github-agent:test pytest

# Test in dev environment
kubectl set image deployment/github-agent \
  github-agent=github-agent:test \
  -n github-agent-dev
```

### Step 2: Deploy to Staging
```bash
# Tag for registry
docker tag github-agent:test harbor.yourdomain.com/agent-staging/github-agent:v1.1.0

# Push to Harbor
docker push harbor.yourdomain.com/agent-staging/github-agent:v1.1.0

# Update staging via ArgoCD or kubectl
```

### Step 3: Monitor & Validate
- Check application logs
- Verify health checks pass
- Run integration tests
- Monitor for 24-48 hours

### Step 4: Deploy to Production
```bash
# Tag for production
docker tag github-agent:test harbor.yourdomain.com/agent-prod/github-agent:v1.1.0

# Push to production registry
docker push harbor.yourdomain.com/agent-prod/github-agent:v1.1.0

# Update production via GitOps
```

## Troubleshooting

### Distroless Image Debugging

Since distroless has no shell, use ephemeral debug containers:

```bash
# Attach debug container to running pod
kubectl debug -it github-agent-pod \
  --image=busybox \
  --target=github-agent

# Or use a debug image with shell
kubectl debug -it github-agent-pod \
  --image=python:3.11-slim \
  --target=github-agent \
  --copy-to=github-agent-debug
```

### Common Issues

**Issue: Application won't start**
```bash
# Check logs
docker logs github-agent

# Run with shell for debugging (optimized image)
docker run -it --entrypoint /bin/bash github-agent:optimized
```

**Issue: Health check fails**
```bash
# Test health endpoint
docker run -p 8000:8000 github-agent:latest
curl http://localhost:8000/health
```

**Issue: Missing dependencies**
```bash
# Verify Python packages
docker run --rm github-agent:latest pip list
```

## Best Practices

1. **Always use multi-stage builds** to separate build and runtime
2. **Run as non-root user** (UID 1000 recommended)
3. **Pin base image versions** (use specific tags, not `latest`)
4. **Scan images regularly** with Trivy/Grype
5. **Use .dockerignore** to exclude unnecessary files
6. **Implement health checks** in Dockerfile
7. **Keep images small** - only include runtime dependencies
8. **Sign images** with cosign for supply chain security

## Performance Tips

1. **Order COPY commands** by frequency of change (least to most)
2. **Leverage BuildKit** cache mounts
3. **Use build cache** in CI/CD
4. **Multi-platform builds** for ARM64/AMD64

```bash
# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f docker/prod-optimized.Dockerfile \
  -t github-agent:latest \
  --push \
  .
```

## CI/CD Integration

Update your Tekton pipeline to use optimized Dockerfile:

```yaml
# In tekton/tasks/build-push-image.yaml
- name: dockerfile
  description: Path to the Dockerfile
  default: ./docker/prod-optimized.Dockerfile  # Changed from prod.Dockerfile
  type: string
```

## Next Steps

1. Choose appropriate Dockerfile for your security requirements
2. Test in dev/staging environments
3. Update CI/CD pipelines
4. Monitor image scan results
5. Gradually migrate to distroless for production
