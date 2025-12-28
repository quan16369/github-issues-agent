#!/bin/bash
# Master installation script for all platform tools
# This script installs all platform tools in the correct order

set -e

echo "GitHub Issue Agent - Platform Tools Installation"
echo "===================================================="
echo ""
echo "This script will install the following components:"
echo "  1. Nginx Ingress Controller"
echo "  2. Cert Manager"
echo "  3. Harbor Container Registry"
echo "  4. Tekton CI/CD"
echo "  5. ArgoCD GitOps"
echo "  6. Observability Stack (Prometheus, Grafana, Jaeger, OTel)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install Nginx Ingress Controller
echo ""
echo "========================================="
echo "Step 1/6: Installing Nginx Ingress"
echo "========================================="
bash "$SCRIPT_DIR/install-nginx-ingress.sh"

# 2. Install Cert Manager
echo ""
echo "========================================="
echo "Step 2/6: Installing Cert Manager"
echo "========================================="
bash "$SCRIPT_DIR/install-cert-manager.sh"

# 3. Install Harbor
echo ""
echo "========================================="
echo "Step 3/6: Installing Harbor"
echo "========================================="
read -p "Enter your Harbor domain (e.g., harbor.yourdomain.com): " HARBOR_DOMAIN
bash "$SCRIPT_DIR/install-harbor.sh" "$HARBOR_DOMAIN"

# 4. Install Tekton
echo ""
echo "========================================="
echo "Step 4/6: Installing Tekton"
echo "========================================="
bash "$SCRIPT_DIR/install-tekton.sh"

# 5. Install ArgoCD
echo ""
echo "========================================="
echo "Step 5/6: Installing ArgoCD"
echo "========================================="
bash "$SCRIPT_DIR/install-argocd.sh"

# 6. Install Observability Stack
echo ""
echo "========================================="
echo "Step 6/6: Installing Observability Stack"
echo "========================================="
bash "$SCRIPT_DIR/install-observability.sh"

echo ""
echo "========================================="
echo "All Platform Tools Installed!"
echo "========================================="
echo ""
echo "Credentials are saved in your home directory:"
echo "  ~/harbor-credentials/credentials.txt"
echo "  ~/argocd-credentials/credentials.txt"
echo "  ~/observability-credentials/credentials.txt"
echo ""
echo "Next steps:"
echo "1. Configure DNS records for your domains"
echo "2. Update email addresses in Cert Manager ClusterIssuers"
echo "3. Create projects in Harbor (agent-dev, agent-staging, agent-prod)"
echo "4. Configure ArgoCD applications for GitOps"
echo "5. Set up Grafana dashboards"
echo ""
echo "See documentation in kubernetes/platform-tools/README.md"
