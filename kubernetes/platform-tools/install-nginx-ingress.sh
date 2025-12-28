#!/bin/bash
# Install Nginx Ingress Controller on GKE
# This script installs the Nginx Ingress Controller using Helm

set -e

NAMESPACE="ingress-nginx"
RELEASE_NAME="ingress-nginx"

echo "Installing Nginx Ingress Controller..."

# Add Helm repository
echo "Adding Nginx Ingress Helm repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install Nginx Ingress Controller
echo "Installing Nginx Ingress Controller..."
helm upgrade --install $RELEASE_NAME ingress-nginx/ingress-nginx \
  --namespace $NAMESPACE \
  --set controller.service.type=LoadBalancer \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.podAnnotations."prometheus\.io/scrape"=true \
  --set controller.podAnnotations."prometheus\.io/port"=10254 \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=128Mi \
  --set controller.resources.limits.cpu=500m \
  --set controller.resources.limits.memory=512Mi \
  --set controller.autoscaling.enabled=true \
  --set controller.autoscaling.minReplicas=2 \
  --set controller.autoscaling.maxReplicas=10 \
  --set controller.autoscaling.targetCPUUtilizationPercentage=80 \
  --set controller.config.use-forwarded-headers="true" \
  --set controller.config.compute-full-forwarded-for="true" \
  --set controller.config.use-proxy-protocol="false" \
  --wait

# Wait for LoadBalancer IP
echo "Waiting for LoadBalancer IP..."
kubectl wait --namespace $NAMESPACE \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Get LoadBalancer IP
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  echo "Waiting for external IP..."
  EXTERNAL_IP=$(kubectl get svc $RELEASE_NAME-controller -n $NAMESPACE \
    --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$EXTERNAL_IP" ] && sleep 10
done

echo ""
echo "Nginx Ingress Controller installed successfully!"
echo "External IP: $EXTERNAL_IP"
echo ""
echo "Configure your DNS records to point to: $EXTERNAL_IP"
echo ""
echo "Test with:"
echo "  curl http://$EXTERNAL_IP"
