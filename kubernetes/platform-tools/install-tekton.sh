#!/bin/bash
# Install Tekton Pipelines for CI/CD
# This script installs Tekton Pipelines, Triggers, and Dashboard

set -e

echo "Installing Tekton Pipelines..."

# Install Tekton Pipelines
TEKTON_VERSION="v0.56.0"
echo "Installing Tekton Pipelines $TEKTON_VERSION..."
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/$TEKTON_VERSION/release.yaml

# Wait for Tekton Pipelines to be ready
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/part-of=tekton-pipelines \
  --namespace tekton-pipelines \
  --timeout=300s

# Install Tekton Triggers
TRIGGERS_VERSION="v0.25.0"
echo "Installing Tekton Triggers $TRIGGERS_VERSION..."
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/previous/$TRIGGERS_VERSION/release.yaml
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/previous/$TRIGGERS_VERSION/interceptors.yaml

# Wait for Tekton Triggers to be ready
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/part-of=tekton-triggers \
  --namespace tekton-pipelines \
  --timeout=300s

# Install Tekton Dashboard
DASHBOARD_VERSION="v0.43.0"
echo "Installing Tekton Dashboard $DASHBOARD_VERSION..."
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/previous/$DASHBOARD_VERSION/release.yaml

# Wait for Dashboard to be ready
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/part-of=tekton-dashboard \
  --namespace tekton-pipelines \
  --timeout=300s

# Install Tekton CLI (optional - for local use)
echo ""
echo "To install Tekton CLI (tkn) locally:"
echo "  # macOS"
echo "  brew install tektoncd-cli"
echo ""
echo "  # Linux"
echo "  curl -LO https://github.com/tektoncd/cli/releases/download/v0.35.0/tkn_0.35.0_Linux_x86_64.tar.gz"
echo "  tar xvzf tkn_0.35.0_Linux_x86_64.tar.gz -C /usr/local/bin/ tkn"
echo ""

# Create Ingress for Tekton Dashboard
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tekton-dashboard
  namespace: tekton-pipelines
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - tekton.example.com  # Change this to your domain
    secretName: tekton-dashboard-tls
  rules:
  - host: tekton.example.com  # Change this to your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tekton-dashboard
            port:
              number: 9097
EOF

# Apply Tekton tasks and pipelines from project
echo "Applying Tekton tasks and pipelines..."
kubectl apply -f /home/quan/github-issue-agent/tekton/tasks/
kubectl apply -f /home/quan/github-issue-agent/tekton/pipelines/

echo ""
echo "Tekton installed successfully!"
echo ""
echo "Access Tekton Dashboard:"
echo "  kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097"
echo "  Open: http://localhost:9097"
echo ""
echo "Or configure DNS for: tekton.example.com"
echo ""
echo "View resources:"
echo "  kubectl get pipelines -n tekton-pipelines"
echo "  kubectl get tasks -n tekton-pipelines"
