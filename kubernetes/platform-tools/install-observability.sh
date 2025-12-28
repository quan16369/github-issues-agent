#!/bin/bash
# Install Observability Stack (Prometheus, Grafana, Jaeger, OpenTelemetry)
# This script installs the complete observability stack using Helm

set -e

MONITORING_NAMESPACE="monitoring"
TRACING_NAMESPACE="tracing"

echo "Installing Observability Stack..."

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Create namespaces
kubectl create namespace $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $TRACING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus + Grafana (kube-prometheus-stack)
echo ""
echo "Installing Prometheus & Grafana..."

cat > /tmp/prometheus-values.yaml <<EOF
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

grafana:
  adminPassword: $(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.example.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.example.com
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-staging"

alertmanager:
  enabled: true
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true
EOF

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace $MONITORING_NAMESPACE \
  --values /tmp/prometheus-values.yaml \
  --wait \
  --timeout 10m

GRAFANA_PASSWORD=$(kubectl get secret -n $MONITORING_NAMESPACE kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

# Install Jaeger for distributed tracing
echo ""
echo "Installing Jaeger..."

cat > /tmp/jaeger-values.yaml <<EOF
provisionDataStore:
  cassandra: false
  elasticsearch: true

storage:
  type: elasticsearch
  elasticsearch:
    scheme: http
    host: elasticsearch
    port: 9200

agent:
  enabled: true

collector:
  enabled: true
  service:
    type: ClusterIP
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

query:
  enabled: true
  service:
    type: ClusterIP
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - jaeger.example.com
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-staging"
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

elasticsearch:
  enabled: true
  replicas: 1
  minimumMasterNodes: 1
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  volumeClaimTemplate:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 30Gi
EOF

helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace $TRACING_NAMESPACE \
  --values /tmp/jaeger-values.yaml \
  --wait \
  --timeout 10m

# Install OpenTelemetry Collector
echo ""
echo "Installing OpenTelemetry Collector..."

cat > /tmp/otel-collector-values.yaml <<EOF
mode: deployment

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    prometheus:
      config:
        scrape_configs:
          - job_name: 'otel-collector'
            scrape_interval: 10s
            static_configs:
              - targets: ['0.0.0.0:8888']

  processors:
    batch:
      timeout: 10s
      send_batch_size: 1024
    memory_limiter:
      check_interval: 1s
      limit_mib: 512

  exporters:
    prometheus:
      endpoint: "0.0.0.0:8889"
    jaeger:
      endpoint: jaeger-collector.$TRACING_NAMESPACE.svc.cluster.local:14250
      tls:
        insecure: true
    logging:
      loglevel: info

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [jaeger, logging]
      metrics:
        receivers: [otlp, prometheus]
        processors: [memory_limiter, batch]
        exporters: [prometheus, logging]

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

service:
  type: ClusterIP
EOF

helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector \
  --namespace $MONITORING_NAMESPACE \
  --values /tmp/otel-collector-values.yaml \
  --wait

# Save credentials
mkdir -p ~/observability-credentials
cat > ~/observability-credentials/credentials.txt <<EOF
Observability Stack Credentials
================================

Grafana:
--------
URL: https://grafana.example.com
Username: admin
Password: $GRAFANA_PASSWORD

Port Forward:
kubectl port-forward -n $MONITORING_NAMESPACE svc/kube-prometheus-stack-grafana 3000:80

Prometheus:
-----------
Port Forward:
kubectl port-forward -n $MONITORING_NAMESPACE svc/kube-prometheus-stack-prometheus 9090:9090

Jaeger:
-------
URL: https://jaeger.example.com
Port Forward:
kubectl port-forward -n $TRACING_NAMESPACE svc/jaeger-query 16686:16686

OpenTelemetry Collector:
------------------------
OTLP gRPC: opentelemetry-collector.$MONITORING_NAMESPACE.svc.cluster.local:4317
OTLP HTTP: opentelemetry-collector.$MONITORING_NAMESPACE.svc.cluster.local:4318
EOF

chmod 600 ~/observability-credentials/credentials.txt

echo ""
echo "Observability Stack installed successfully!"
echo ""
echo "Credentials saved to: ~/observability-credentials/credentials.txt"
echo ""
echo "Access Grafana:"
echo "  URL: https://grafana.example.com"
echo "  Username: admin"
echo "  Password: $GRAFANA_PASSWORD"
echo "  Port Forward: kubectl port-forward -n $MONITORING_NAMESPACE svc/kube-prometheus-stack-grafana 3000:80"
echo ""
echo "Access Prometheus:"
echo "  Port Forward: kubectl port-forward -n $MONITORING_NAMESPACE svc/kube-prometheus-stack-prometheus 9090:9090"
echo ""
echo "Access Jaeger:"
echo "  URL: https://jaeger.example.com"
echo "  Port Forward: kubectl port-forward -n $TRACING_NAMESPACE svc/jaeger-query 16686:16686"
echo ""
echo "Instrument your application with OpenTelemetry:"
echo "  OTLP Endpoint: http://opentelemetry-collector.$MONITORING_NAMESPACE.svc.cluster.local:4318"
