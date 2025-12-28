#!/bin/bash
# Install Cert Manager for automated SSL certificate management
# This script installs Cert Manager using Helm

set -e

NAMESPACE="cert-manager"
RELEASE_NAME="cert-manager"
VERSION="v1.14.1"

echo "Installing Cert Manager..."

# Add Helm repository
echo "Adding Cert Manager Helm repository..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install Cert Manager CRDs
echo "Installing Cert Manager CRDs..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$VERSION/cert-manager.crds.yaml

# Install Cert Manager
echo "Installing Cert Manager..."
helm upgrade --install $RELEASE_NAME jetstack/cert-manager \
  --namespace $NAMESPACE \
  --version $VERSION \
  --set installCRDs=false \
  --set prometheus.enabled=true \
  --set prometheus.servicemonitor.enabled=true \
  --wait

# Wait for pods to be ready
kubectl wait --namespace $NAMESPACE \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=300s

# Create ClusterIssuer for Let's Encrypt staging
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com  # Change this to your email
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Create ClusterIssuer for Let's Encrypt production
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com  # Change this to your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo ""
echo "Cert Manager installed successfully!"
echo ""
echo "Available ClusterIssuers:"
echo "  - letsencrypt-staging (for testing)"
echo "  - letsencrypt-prod (for production)"
echo ""
echo "Update the email address in ClusterIssuers:"
echo "  kubectl edit clusterissuer letsencrypt-staging"
echo "  kubectl edit clusterissuer letsencrypt-prod"
