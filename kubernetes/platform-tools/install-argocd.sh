#!/bin/bash
# Install ArgoCD for GitOps continuous delivery
# This script installs ArgoCD using kubectl

set -e

NAMESPACE="argocd"
VERSION="v2.10.0"

echo "Installing ArgoCD..."

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "Installing ArgoCD $VERSION..."
kubectl apply -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/$VERSION/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --namespace $NAMESPACE \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=300s

# Patch ArgoCD server to use LoadBalancer (optional)
# kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Create Ingress for ArgoCD
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argocd.example.com  # Change this to your domain
    secretName: argocd-server-tls
  rules:
  - host: argocd.example.com  # Change this to your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
EOF

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Save credentials
mkdir -p ~/argocd-credentials
cat > ~/argocd-credentials/credentials.txt <<EOF
ArgoCD Installation Credentials
================================
URL: https://argocd.example.com (or use port-forward)
Username: admin
Password: $ARGOCD_PASSWORD

Port Forward Command:
kubectl port-forward svc/argocd-server -n argocd 8080:443

Then access: https://localhost:8080
EOF

chmod 600 ~/argocd-credentials/credentials.txt

echo ""
echo "ArgoCD installed successfully!"
echo ""
echo "Credentials saved to: ~/argocd-credentials/credentials.txt"
echo ""
echo "Access ArgoCD:"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "Port forward to access:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Open: https://localhost:8080"
echo ""
echo "Install ArgoCD CLI:"
echo "  # macOS"
echo "  brew install argocd"
echo ""
echo "  # Linux"
echo "  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64"
echo "  chmod +x /usr/local/bin/argocd"
echo ""
echo "Login via CLI:"
echo "  argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure"
echo ""
echo "Change password:"
echo "  argocd account update-password"
