#!/bin/bash
# Install Harbor Container Registry with Trivy Scanner
# This script installs Harbor using Helm

set -e

NAMESPACE="harbor"
RELEASE_NAME="harbor"
DOMAIN="${1:-harbor.example.com}"  # Pass domain as argument

if [ "$DOMAIN" = "harbor.example.com" ]; then
  echo "Warning: Using default domain. Pass your domain as argument:"
  echo "   $0 harbor.yourdomain.com"
  echo ""
fi

echo "Installing Harbor Container Registry..."
echo "Domain: $DOMAIN"

# Add Helm repository
echo "Adding Harbor Helm repository..."
helm repo add harbor https://helm.goharbor.io
helm repo update

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Generate random passwords
ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Create values file
cat > /tmp/harbor-values.yaml <<EOF
expose:
  type: ingress
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: "harbor-tls"
      notarySecretName: "notary-tls"
  ingress:
    hosts:
      core: $DOMAIN
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-staging"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"

externalURL: https://$DOMAIN

persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      size: 50Gi
    chartmuseum:
      size: 5Gi
    jobservice:
      size: 1Gi
    database:
      size: 5Gi
    redis:
      size: 1Gi
    trivy:
      size: 5Gi

harborAdminPassword: "$ADMIN_PASSWORD"

database:
  type: internal
  internal:
    password: "$POSTGRES_PASSWORD"

trivy:
  enabled: true
  gitHubToken: ""
  skipUpdate: false
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

core:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

portal:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

registry:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

# Enable image scanning on push
scannerAdapter:
  enabled: true
EOF

# Install Harbor
echo "Installing Harbor..."
helm upgrade --install $RELEASE_NAME harbor/harbor \
  --namespace $NAMESPACE \
  --values /tmp/harbor-values.yaml \
  --wait \
  --timeout 15m

# Wait for pods to be ready
echo "Waiting for Harbor pods to be ready..."
kubectl wait --namespace $NAMESPACE \
  --for=condition=ready pod \
  --selector=app=harbor \
  --timeout=600s

# Save credentials
mkdir -p ~/harbor-credentials
cat > ~/harbor-credentials/credentials.txt <<EOF
Harbor Installation Credentials
================================
URL: https://$DOMAIN
Username: admin
Password: $ADMIN_PASSWORD

Database Password: $POSTGRES_PASSWORD

Projects to create:
- agent-dev
- agent-staging
- agent-prod
EOF

chmod 600 ~/harbor-credentials/credentials.txt

echo ""
echo "Harbor installed successfully!"
echo ""
echo "Credentials saved to: ~/harbor-credentials/credentials.txt"
echo ""
echo "Access Harbor at: https://$DOMAIN"
echo "Username: admin"
echo "Password: $ADMIN_PASSWORD"
echo ""
echo "Next steps:"
echo "1. Create projects in Harbor UI:"
echo "   - agent-dev"
echo "   - agent-staging"
echo "   - agent-prod"
echo ""
echo "2. Configure Docker to use Harbor:"
echo "   docker login $DOMAIN"
echo ""
echo "3. Create robot accounts for CI/CD in Harbor UI"
