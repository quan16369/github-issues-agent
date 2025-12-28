# Grafana Dashboards

Pre-configured dashboards for monitoring the GitHub Issue Agent application.

## Dashboards

### 1. Overview Dashboard (`overview.json`)

**Purpose:** High-level application health and performance

**Panels:**
- **Request Rate** - Issues processed per second (success/failed)
- **Average Latency** - P50, P95, P99 processing time
- **Total Issues Processed** - Cumulative counter
- **Failed Issues** - Error count with color thresholds
- **Success Rate** - Percentage gauge (90%→yellow, 95%→green)
- **Current Request Rate** - Real-time requests/sec
- **Error Rate by Type** - Table of error types
- **Latency Distribution** - Heatmap of response times

**Best For:** SRE on-call, production monitoring, SLA tracking

### 2. Agent Performance Dashboard (`agent-performance.json`)

**Purpose:** Detailed agent execution metrics

**Panels:**
- **Agent Execution Rate** - Executions per second by agent
- **Agent Execution Duration** - Average latency per agent:
  - Input Guardrail
  - Issue Search
  - Classification
  - Recommendation
  - Output Guardrail
- **Agent Stats** - Execution counts for each agent
- **Agent Error Rate** - Errors per second by agent
- **Agent P95 Latency** - 95th percentile latency
- **Guardrail Blocks** - Blocking rate by guardrail type

**Best For:** Performance tuning, identifying slow agents, debugging workflow issues

### 3. Business Metrics Dashboard (`business-metrics.json`)

**Purpose:** Business KPIs and resource usage

**Panels:**
- **Issues Processed (6h/24h)** - Volume metrics
- **OpenAI Tokens Consumed** - Token usage tracking
- **Guardrail Block Rate** - Percentage of blocked requests
- **Issues Over Time** - Hourly bar chart
- **Token Usage Over Time** - By model
- **OpenAI API Requests** - Request rate
- **Estimated Cost** - USD estimate (configurable rate)
- **Vector Search Performance** - Searches/sec
- **Vector Search Latency** - Avg and P95

**Best For:** Cost tracking, capacity planning, business reporting

## Installation

### Option 1: Helm Chart (Recommended)

Add dashboards to kube-prometheus-stack values:

```yaml
# kubernetes/platform-tools/observability-values.yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'github-agent'
          orgId: 1
          folder: 'GitHub Agent'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/github-agent
  
  dashboardsConfigMaps:
    github-agent: grafana-dashboards
```

Deploy ConfigMap:
```bash
kubectl create configmap grafana-dashboards \
  -n observability \
  --from-file=dashboards/ \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Option 2: Manual Import

1. **Access Grafana:**
   ```bash
   kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80
   open http://localhost:3000
   ```

2. **Default Credentials:**
   - Username: `admin`
   - Password: Get from secret
     ```bash
     kubectl get secret -n observability kube-prometheus-stack-grafana \
       -o jsonpath="{.data.admin-password}" | base64 --decode
     ```

3. **Import Dashboards:**
   - Click **+** (Create) → **Import**
   - Upload JSON file or paste content
   - Select Prometheus data source
   - Click **Import**

### Option 3: Kubernetes ConfigMap

```bash
kubectl apply -f grafana/dashboards-configmap.yaml
```

Restart Grafana to load dashboards:
```bash
kubectl rollout restart -n observability deployment/kube-prometheus-stack-grafana
```

## Configuration

### Data Source

All dashboards use the default Prometheus data source. If you have a custom data source:

1. Edit dashboard JSON
2. Find: `"datasource": "Prometheus"`
3. Replace with your data source name

### Refresh Interval

Default refresh rates:
- **Overview:** 30 seconds
- **Agent Performance:** 30 seconds
- **Business Metrics:** 1 minute

To change:
```json
{
  "refresh": "10s"  // or "30s", "1m", "5m"
}
```

### Time Range

Default: Last 1 hour (Overview/Agents), Last 6 hours (Business)

To change:
```json
{
  "time": {
    "from": "now-24h",
    "to": "now"
  }
}
```

### Cost Estimation

The "Estimated OpenAI Cost" panel uses a hardcoded rate of $0.02/1000 tokens.

To adjust for your pricing:
```json
{
  "expr": "sum(increase(openai_tokens_consumed_total[6h])) * YOUR_RATE"
}
```

Example rates:
- GPT-4: $0.00002/token (mixed input/output)
- GPT-3.5-turbo: $0.000002/token

## Dashboard Variables

### Adding Environment Filter

To filter by environment (dev/staging/prod):

1. **Add Variable:**
   ```json
   "templating": {
     "list": [
       {
         "name": "environment",
         "type": "query",
         "query": "label_values(issues_processed_total, environment)",
         "multi": true,
         "includeAll": true
       }
     ]
   }
   ```

2. **Update Queries:**
   ```promql
   rate(issues_processed_total{environment=~"$environment"}[5m])
   ```

### Adding Pod Filter

Filter by specific pod:
```json
{
  "name": "pod",
  "type": "query",
  "query": "label_values(issues_processed_total, pod)"
}
```

## Alert Integration

Link dashboards to alerts by adding annotation queries:

```json
{
  "annotations": {
    "list": [
      {
        "datasource": "Prometheus",
        "enable": true,
        "expr": "ALERTS{alertname=~\".*IssueAgent.*\"}",
        "name": "Alerts",
        "step": "60s"
      }
    ]
  }
}
```

## Customization

### Adding Panels

1. **Edit Dashboard** in Grafana UI
2. **Add Panel**
3. **Write PromQL Query**
4. **Configure Visualization**
5. **Save**
6. **Export JSON**
7. **Update ConfigMap**

### Common PromQL Queries

```promql
# Request rate (last 5 min)
rate(issues_processed_total[5m])

# Error rate percentage
100 * sum(rate(issues_failed_total[5m])) / (sum(rate(issues_processed_total[5m])) + sum(rate(issues_failed_total[5m])))

# Average latency
rate(issue_processing_duration_seconds_sum[5m]) / rate(issue_processing_duration_seconds_count[5m])

# P95 latency
histogram_quantile(0.95, rate(issue_processing_duration_seconds_bucket[5m]))

# Agent success rate
sum by (agent) (rate(agent_executions_total{status="success"}[5m]))

# Tokens per request (average)
rate(openai_tokens_consumed_total[5m]) / rate(openai_requests_total[5m])

# Guardrail block percentage
100 * sum(rate(guardrail_blocks_total[5m])) / sum(rate(agent_executions_total{agent=~".*guardrail"}[5m]))
```

### Useful Visualizations

- **Stat** - Single number (totals, percentages)
- **Gauge** - Value with thresholds (success rate, CPU)
- **Graph** - Time series (rates, latencies)
- **Table** - Multi-dimensional data (errors by type)
- **Heatmap** - Distribution over time (latency buckets)
- **Bar Gauge** - Compare multiple metrics

## Troubleshooting

### No Data Appearing

```bash
# Check Prometheus is scraping metrics
kubectl port-forward -n observability svc/prometheus 9090:9090
open http://localhost:9090/targets

# Verify metrics exist
curl http://localhost:8001/metrics | grep issues_processed

# Check Grafana data source
# Grafana UI → Configuration → Data Sources → Prometheus → Test
```

### Dashboard Not Loading

```bash
# Check ConfigMap exists
kubectl get cm -n observability grafana-dashboards

# Check Grafana logs
kubectl logs -n observability -l app.kubernetes.io/name=grafana --tail=100
```

### Wrong Data Source

If dashboards show "Data source not found":

1. Go to dashboard settings (gear icon)
2. **Variables** tab
3. Update data source UID
4. Or set to use default Prometheus

## Best Practices

1. **Use Variables** for environment/pod filtering
2. **Add Annotations** to mark deployments, incidents
3. **Set Alert Thresholds** on critical panels
4. **Export Regularly** to version control
5. **Document Custom Panels** with descriptions
6. **Use Folders** to organize dashboards
7. **Enable Auto-Refresh** for monitoring views
8. **Add Links** between related dashboards
9. **Set Appropriate Time Ranges** (1h for ops, 24h for trends)
10. **Test Queries** in Prometheus UI first

## Dashboard Links

Add navigation between dashboards:

```json
{
  "links": [
    {
      "title": "Agent Performance",
      "type": "dashboards",
      "url": "/d/github-agent-agents"
    },
    {
      "title": "Business Metrics",
      "type": "dashboards",
      "url": "/d/github-agent-business"
    }
  ]
}
```

## Screenshots

### Overview Dashboard
Shows request rate, latency distribution, success rate gauge, and error breakdown.

### Agent Performance
Detailed timing for each agent node in the workflow, with P95 latency tracking.

### Business Metrics
Token usage, cost estimation, issue volume trends, and vector search performance.

## Next Steps

1. Dashboards created
2. Configure alerts (Task 25)
3. Setup notification channels (Slack/Email)
4. Create custom business metrics
5. Define SLOs and error budgets

## References

- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
