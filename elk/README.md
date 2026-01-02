# ELK Stack for Kubernetes Logging

Complete ELK (Elasticsearch, Logstash, Kibana) Stack deployment for centralized logging and log analysis.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐                    │
│  │   Pod 1      │      │   Pod 2      │                    │
│  │ Application  │      │ Application  │                    │
│  └──────┬───────┘      └──────┬───────┘                    │
│         │ logs                 │ logs                        │
│         ▼                      ▼                             │
│  ┌────────────────────────────────────┐                    │
│  │     Filebeat DaemonSet             │ ← Collect logs     │
│  │  (runs on every node)              │                    │
│  └────────────────┬───────────────────┘                    │
│                   │                                          │
│                   ▼                                          │
│  ┌────────────────────────────────────┐                    │
│  │       Elasticsearch                │ ← Store & Index    │
│  │    (StatefulSet - 10Gi PVC)        │                    │
│  └────────────────┬───────────────────┘                    │
│                   │                                          │
│                   ▼                                          │
│  ┌────────────────────────────────────┐                    │
│  │           Kibana                   │ ← Visualize        │
│  │      (Web UI on port 5601)         │                    │
│  └────────────────┬───────────────────┘                    │
│                   │                                          │
└───────────────────┼──────────────────────────────────────────┘
                    │
                    ▼
            ┌───────────────┐
            │    Ingress    │
            │ kibana.*.com  │
            └───────────────┘
```

## Components

### 1. Elasticsearch
- **Type:** StatefulSet
- **Purpose:** Store and index logs
- **Storage:** 10Gi persistent volume
- **Memory:** 512Mi-2Gi
- **Ports:** 9200 (HTTP), 9300 (Transport)

### 2. Kibana
- **Type:** Deployment
- **Purpose:** Web UI for log visualization and search
- **Memory:** 512Mi-1Gi
- **Port:** 5601
- **Access:** Via Ingress at `kibana.example.com`

### 3. Filebeat
- **Type:** DaemonSet (runs on all nodes)
- **Purpose:** Collect container logs from `/var/log/containers/*.log`
- **Features:**
  - Auto-discovery of Kubernetes pods
  - Kubernetes metadata enrichment
  - Filter out kube-system logs
  - Index by namespace

## Deployment

### Prerequisites
- Kubernetes cluster (GKE/EKS/AKS)
- `kubectl` configured
- StorageClass `standard` available
- Ingress controller (nginx) installed

### Quick Start

```bash
# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Deploy Elasticsearch
kubectl apply -f elasticsearch-statefulset.yaml
kubectl apply -f elasticsearch-service.yaml

# Wait for Elasticsearch to be ready
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

# 3. Deploy Kibana
kubectl apply -f kibana-deployment.yaml
kubectl apply -f kibana-service.yaml

# 4. Deploy Filebeat
kubectl apply -f filebeat-rbac.yaml
kubectl apply -f filebeat-configmap.yaml
kubectl apply -f filebeat-daemonset.yaml

# 5. Setup Ingress (optional)
kubectl apply -f kibana-ingress.yaml
```

### Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n logging

# Expected output:
# NAME                      READY   STATUS    RESTARTS   AGE
# elasticsearch-0           1/1     Running   0          2m
# kibana-6f7d8b4c9d-xxxxx  1/1     Running   0          1m
# filebeat-xxxxx            1/1     Running   0          1m
# filebeat-yyyyy            1/1     Running   0          1m

# Check services
kubectl get svc -n logging

# Port-forward Kibana for local access
kubectl port-forward -n logging svc/kibana 5601:5601
```

### Access Kibana

**Option 1: Port-forward (Development)**
```bash
kubectl port-forward -n logging svc/kibana 5601:5601
# Access at: http://localhost:5601
```

**Option 2: Ingress (Production)**
```bash
# Update kibana-ingress.yaml with your domain
# Access at: https://kibana.yourdomain.com
```

## Configuration

### Elasticsearch

**Storage:**
```yaml
storage: 10Gi  # Adjust based on log volume
storageClassName: standard  # Change to your storage class
```

**Memory:**
```yaml
ES_JAVA_OPTS: "-Xms512m -Xmx512m"  # Increase for production
```

### Filebeat

**Log Paths:**
```yaml
paths:
  - /var/log/containers/*.log  # All container logs
```

**Filtering:**
- Excludes `kube-system` and `kube-public` namespaces
- Add more filters in `filebeat-configmap.yaml`

**Index Naming:**
- `github-agent-*` → Application logs from default namespace
- `kubernetes-*` → Other Kubernetes logs

## Kibana Setup

1. **Open Kibana:** http://localhost:5601 or your ingress URL

2. **Create Index Pattern:**
   - Go to: Management → Stack Management → Index Patterns
   - Create pattern: `github-agent-*`
   - Select timestamp field: `@timestamp`
   - Create pattern: `kubernetes-*`

3. **Discover Logs:**
   - Go to: Analytics → Discover
   - Select index pattern
   - Filter by namespace, pod, container

4. **Create Visualizations:**
   - Go to: Analytics → Visualize
   - Create charts based on log data

5. **Build Dashboards:**
   - Go to: Analytics → Dashboard
   - Combine visualizations

## Common Queries

### View Application Logs
```
kubernetes.namespace: "default" AND kubernetes.container.name: "github-agent"
```

### Filter by Log Level
```
message: "ERROR" OR message: "WARN"
```

### Last 15 Minutes
```
@timestamp: [now-15m TO now]
```

### Specific Pod
```
kubernetes.pod.name: "github-agent-*"
```

## Monitoring

### Check Elasticsearch Health
```bash
kubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cluster/health?pretty
```

### Check Indices
```bash
kubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cat/indices?v
```

### Check Filebeat Status
```bash
kubectl logs -n logging -l app=filebeat --tail=50
```

## Troubleshooting

### Elasticsearch Not Starting

**Issue:** Pod stuck in Pending
```bash
# Check PVC status
kubectl get pvc -n logging

# Check events
kubectl describe statefulset elasticsearch -n logging
```

**Solution:**
- Ensure StorageClass exists: `kubectl get sc`
- Check node resources: `kubectl describe nodes`

### Kibana Connection Error

**Issue:** Cannot connect to Elasticsearch
```bash
# Check Elasticsearch service
kubectl get svc elasticsearch -n logging

# Check Kibana logs
kubectl logs -n logging -l app=kibana
```

### Filebeat Not Collecting Logs

**Issue:** No logs in Elasticsearch
```bash
# Check Filebeat logs
kubectl logs -n logging -l app=filebeat --tail=100

# Verify RBAC permissions
kubectl auth can-i list pods --as=system:serviceaccount:logging:filebeat
```

## Scaling

### Scale Elasticsearch (High Availability)

```yaml
# Update elasticsearch-statefulset.yaml
replicas: 3  # 3-node cluster

# Enable cluster discovery
env:
  - name: discovery.seed_hosts
    value: "elasticsearch-0.elasticsearch,elasticsearch-1.elasticsearch,elasticsearch-2.elasticsearch"
  - name: cluster.initial_master_nodes
    value: "elasticsearch-0,elasticsearch-1,elasticsearch-2"
```

### Increase Storage

```bash
# Not possible to resize PVC in place for StatefulSets
# Need to create new PVC and migrate data or use volume expansion if supported
kubectl get sc standard -o yaml | grep allowVolumeExpansion
```

## Log Retention

### Index Lifecycle Management (ILM)

Filebeat automatically configures ILM policies:
- **Hot phase:** 7 days
- **Warm phase:** 30 days
- **Delete phase:** 90 days

Customize in `filebeat-configmap.yaml`:
```yaml
setup.ilm.policy:
  phases:
    hot:
      actions:
        rollover:
          max_age: 7d
    delete:
      min_age: 90d
```

## Production Considerations

### Security

1. **Enable Elasticsearch Security:**
```yaml
env:
  - name: xpack.security.enabled
    value: "true"
  - name: ELASTIC_PASSWORD
    valueFrom:
      secretKeyRef:
        name: elasticsearch-credentials
        key: password
```

2. **Enable TLS:**
```yaml
env:
  - name: xpack.security.http.ssl.enabled
    value: "true"
```

3. **Network Policies:**
```bash
# Allow only Filebeat and Kibana to access Elasticsearch
kubectl apply -f network-policy.yaml
```

### Resource Limits

**Production values:**
```yaml
# Elasticsearch
resources:
  requests:
    memory: "4Gi"
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"

# Kibana
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### Backup

```bash
# Create snapshot repository
kubectl exec -n logging elasticsearch-0 -- curl -X PUT "localhost:9200/_snapshot/backup" \
  -H 'Content-Type: application/json' -d'{
  "type": "gcs",
  "settings": {
    "bucket": "my-backup-bucket",
    "base_path": "elasticsearch-snapshots"
  }
}'

# Create snapshot
kubectl exec -n logging elasticsearch-0 -- curl -X PUT "localhost:9200/_snapshot/backup/snapshot_1?wait_for_completion=true"
```

## Integration with Observability Stack

ELK Stack complements existing observability tools:

| Component | Purpose | Tool |
|-----------|---------|------|
| **Metrics** | Performance monitoring | Prometheus + Grafana |
| **Traces** | Request flow tracking | Jaeger + OpenTelemetry |
| **Logs** | Event & error analysis | **ELK Stack** |

### Correlating Logs with Traces

Use trace IDs in logs:
```python
# In application code
logger.info(f"Processing request trace_id={trace_id}")
```

Search in Kibana:
```
trace_id: "abc123xyz"
```

## Uninstall

```bash
# Delete all resources
kubectl delete -f ./ -n logging

# Delete namespace
kubectl delete namespace logging

# Delete PVCs (careful!)
kubectl delete pvc -n logging --all
```

## Resources

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana User Guide](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Filebeat Reference](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)
- [Kubernetes Logging Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/logging/)

## Support

For issues or questions:
1. Check logs: `kubectl logs -n logging <pod-name>`
2. Verify configuration: `kubectl describe -n logging <resource>`
3. Review Elasticsearch cluster health
4. Check Filebeat indices in Kibana
