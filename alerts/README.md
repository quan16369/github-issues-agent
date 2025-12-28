# Alerting Configuration

Complete alerting setup for GitHub Issue Agent with Slack and Email notifications.

## Alert Rules

### SLO Alerts

| Alert | Threshold | Duration | Severity | Description |
|-------|-----------|----------|----------|-------------|
| **HighErrorRate** | >5% | 5m | warning | Error rate exceeds 5% |
| **CriticalErrorRate** | >15% | 2m | critical | Error rate exceeds 15% |
| **HighLatency** | P95 >2s | 5m | warning | 95th percentile latency >2s |
| **CriticalLatency** | P95 >5s | 2m | critical | 95th percentile latency >5s |

### Agent Alerts

| Alert | Threshold | Duration | Severity | Description |
|-------|-----------|----------|----------|-------------|
| **AgentHighFailureRate** | >10% | 5m | warning | Agent failure rate >10% |
| **SlowAgentExecution** | Avg >0.5s | 10m | warning | Non-LLM agent slow |
| **SlowLLMAgentExecution** | Avg >3s | 10m | warning | LLM agent slow |

### Resource Alerts

| Alert | Threshold | Duration | Severity | Description |
|-------|-----------|----------|----------|-------------|
| **HighTokenConsumption** | >100k/hour | 5m | warning | High OpenAI token usage |
| **HighOpenAICost** | >$10/6h | 1m | warning | High OpenAI costs |
| **SlowVectorSearch** | P95 >1s | 5m | warning | Qdrant search degraded |

### Guardrail Alerts

| Alert | Threshold | Duration | Severity | Description |
|-------|-----------|----------|----------|-------------|
| **HighGuardrailBlockRate** | >20% | 10m | warning | Many requests blocked |
| **UnusualGuardrailActivity** | >5 blocks/sec | 5m | info | Unusual block pattern |

### Availability Alerts

| Alert | Threshold | Duration | Severity | Description |
|-------|-----------|----------|----------|-------------|
| **PodDown** | Pod not Running | 2m | critical | Pod crashed or pending |
| **MultiplePodsDown** | >1 pod down | 1m | critical | Multiple pods unavailable |
| **NoRequestsReceived** | 0 req/sec | 10m | warning | No traffic received |

### Database Alerts

| Alert | Threshold | Duration | Severity | Description |
|-------|-----------|----------|----------|-------------|
| **DatabaseConnectionErrors** | >0.1/sec | 5m | critical | Cloud SQL connection issues |

## Installation

### 1. Create Secrets

```bash
# Slack webhook
kubectl create secret generic alertmanager-slack-webhook \
  -n observability \
  --from-literal=slack-webhook-url='https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

# Email SMTP password
kubectl create secret generic alertmanager-email-config \
  -n observability \
  --from-literal=smtp-password='YOUR_SMTP_PASSWORD'
```

### 2. Deploy Alert Rules

```bash
kubectl apply -f alerts/prometheus-rules.yaml
```

### 3. Configure Alertmanager

```bash
kubectl apply -f alerts/alertmanager-config.yaml
```

### 4. Verify Installation

```bash
# Check PrometheusRule
kubectl get prometheusrule -n default github-agent-alerts

# Check Alertmanager config
kubectl get configmap -n observability alertmanager-config

# Check secrets
kubectl get secrets -n observability | grep alert
```

## Slack Setup

### 1. Create Slack App

1. Go to [https://api.slack.com/apps](https://api.slack.com/apps)
2. **Create New App** → **From scratch**
3. Name: `Prometheus Alerts`
4. Workspace: Your workspace

### 2. Enable Incoming Webhooks

1. **Features** → **Incoming Webhooks** → **Activate**
2. **Add New Webhook to Workspace**
3. Select channel (e.g., `#alerts`, `#critical-alerts`, `#warnings`)
4. Copy webhook URL

### 3. Create Channels

```
#critical-alerts  - Critical issues (PagerDuty integration)
#warnings         - Warning-level alerts
#info-alerts      - Informational alerts
```

### 4. Update Secret

```bash
kubectl create secret generic alertmanager-slack-webhook \
  -n observability \
  --from-literal=slack-webhook-url='YOUR_WEBHOOK_URL' \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Email Setup

### Using Gmail SMTP

```yaml
email_configs:
  - to: 'sre-team@example.com'
    from: 'alerts@example.com'
    smarthost: 'smtp.gmail.com:587'
    auth_username: 'alerts@example.com'
    auth_password_file: /etc/alertmanager/secrets/email/smtp-password
```

**Gmail App Password:**
1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Enable 2-Step Verification
3. **App passwords** → Select app → Generate
4. Use generated password in secret

### Using SendGrid

```yaml
email_configs:
  - to: 'sre-team@example.com'
    from: 'alerts@example.com'
    smarthost: 'smtp.sendgrid.net:587'
    auth_username: 'apikey'
    auth_password_file: /etc/alertmanager/secrets/email/smtp-password
```

Secret should contain SendGrid API key.

## Alert Routing

### Routing Tree

```
All Alerts
├── severity=critical → critical-alerts (Slack + Email)
├── severity=warning  → warning-alerts (Slack only)
└── severity=info     → info-alerts (Slack, no resolve)
```

### Inhibition Rules

- **Critical inhibits Warning** - If critical alert firing, suppress warning for same component
- **MultiplePodsDown inhibits PodDown** - If multiple pods down, suppress individual pod alerts

## Testing Alerts

### 1. Trigger Test Alert

```bash
# Generate high load to trigger HighLatency
for i in {1..100}; do
  curl -X POST http://github-agent:8000/process-issue \
    -H "Content-Type: application/json" \
    -d '{"title":"Test","body":"Test body"}' &
done
```

### 2. Silence Alerts (Testing)

```bash
# Port-forward Alertmanager
kubectl port-forward -n observability svc/alertmanager 9093:9093

# Create silence via UI
open http://localhost:9093
```

### 3. Check Alert State

```bash
# View firing alerts in Prometheus
kubectl port-forward -n observability svc/prometheus 9090:9090
open http://localhost:9090/alerts

# View in Alertmanager
kubectl port-forward -n observability svc/alertmanager 9093:9093
open http://localhost:9093
```

## Customization

### Adjust Thresholds

Edit [prometheus-rules.yaml](prometheus-rules.yaml):

```yaml
- alert: HighErrorRate
  expr: |
    (sum(rate(issues_failed_total[5m])) / ...) * 100 > 10  # Change from 5 to 10
  for: 10m  # Change from 5m to 10m
```

Apply changes:
```bash
kubectl apply -f alerts/prometheus-rules.yaml
```

### Add New Alert

```yaml
- alert: CustomAlert
  expr: your_promql_query > threshold
  for: 5m
  labels:
    severity: warning
    component: custom
  annotations:
    summary: "Custom alert summary"
    description: "Description with value: {{ $value }}"
```

### Add PagerDuty Integration

```yaml
receivers:
  - name: 'critical-alerts'
    pagerduty_configs:
      - routing_key: 'YOUR_PAGERDUTY_KEY'
        description: '{{ .GroupLabels.alertname }}'
```

## Alert Examples

### High Error Rate Notification

**Slack:**
```
CRITICAL: CriticalErrorRate
Alert: Critical error rate detected
Description: Error rate is 18.5% (threshold: 15%)
Severity: critical
Component: api
[View in Grafana] [View Logs]
```

**Email:**
```
Subject: CRITICAL: CriticalErrorRate

Critical Alert
Alert: Critical error rate detected
Description: Error rate is 18.5% (threshold: 15%)
Severity: critical
Component: api
```

### Agent Slow Notification

**Slack:**
```
WARNING: SlowAgentExecution
Alert: Agent issue_search is slow
Description: Agent issue_search avg duration: 750ms
Component: agent
```

## Runbooks

Link alerts to runbooks:

```yaml
annotations:
  summary: "High error rate detected"
  description: "Error rate is {{ $value | humanizePercentage }}"
  runbook_url: "https://wiki.example.com/runbooks/high-error-rate"
```

### Example Runbook Structure

**High Error Rate Runbook:**
1. Check Grafana dashboard for patterns
2. View recent deployments (ArgoCD)
3. Check application logs for errors
4. Verify external dependencies (Cloud SQL, Qdrant)
5. Scale up pods if needed
6. Rollback if related to recent deployment

## Monitoring Alertmanager

### Check Status

```bash
# Alertmanager UI
kubectl port-forward -n observability svc/alertmanager 9093:9093
open http://localhost:9093

# Check config
curl http://localhost:9093/api/v1/status

# Check receivers
curl http://localhost:9093/api/v1/receivers
```

### View Alert History

Alerts are also recorded in Prometheus:
```promql
ALERTS{alertname="HighErrorRate"}
ALERTS_FOR_STATE{alertname="HighErrorRate"}
```

## Troubleshooting

### Alerts Not Firing

```bash
# Check Prometheus rules loaded
kubectl get prometheusrule -A

# Verify rule evaluation
kubectl port-forward -n observability svc/prometheus 9090:9090
# Go to http://localhost:9090/rules

# Check expression in Prometheus
# Alerts → Select alert → View expression
```

### Slack Notifications Not Received

```bash
# Check Alertmanager logs
kubectl logs -n observability -l app=alertmanager --tail=100

# Test webhook manually
curl -X POST 'YOUR_WEBHOOK_URL' \
  -H 'Content-Type: application/json' \
  -d '{"text":"Test notification"}'

# Verify secret exists
kubectl get secret -n observability alertmanager-slack-webhook
```

### Email Not Sent

```bash
# Check Alertmanager logs for SMTP errors
kubectl logs -n observability -l app=alertmanager | grep -i smtp

# Test SMTP connection
kubectl run -it --rm debug --image=alpine --restart=Never -- \
  sh -c "apk add openssl && openssl s_client -connect smtp.gmail.com:587 -starttls smtp"
```

### Wrong Alert Severity

Check routing config:
```bash
kubectl get cm -n observability alertmanager-config -o yaml
```

Verify alert labels match routes.

## Best Practices

1. **Use Severity Labels** - critical/warning/info
2. **Group Related Alerts** - group_by in routes
3. **Set Appropriate Durations** - Avoid alert flapping
4. **Add Runbook Links** - Help on-call engineers
5. **Test Alerts Regularly** - Monthly alert drills
6. **Review and Tune** - Adjust thresholds based on actual usage
7. **Silence During Maintenance** - Use Alertmanager silences
8. **Document Escalation** - Who gets paged for what
9. **Use Inhibition** - Avoid alert storms
10. **Monitor Alert Volume** - Too many alerts = alert fatigue

## Integration with ArgoCD

Add ArgoCD sync alerts:

```yaml
- alert: ArgoCDSyncFailed
  expr: argocd_app_sync_total{phase="Failed"} > 0
  for: 2m
  labels:
    severity: critical
    component: deployment
  annotations:
    summary: "ArgoCD sync failed for {{ $labels.name }}"
```

## Metrics Dashboard

Create Grafana dashboard for alert metrics:

```promql
# Total alerts firing
count(ALERTS{alertstate="firing"})

# Alerts by severity
count by (severity) (ALERTS{alertstate="firing"})

# Alert duration
ALERTS_FOR_STATE

# Notifications sent
rate(alertmanager_notifications_total[5m])

# Failed notifications
rate(alertmanager_notifications_failed_total[5m])
```

## Next Steps

1. Alerts configured
2. Setup PagerDuty integration (optional)
3. Write runbooks for each alert
4. Define SLOs and error budgets
5. Create alert dashboard in Grafana
6. Schedule monthly alert review

## References

- [Prometheus Alerting](https://prometheus.io/docs/alerting/latest/overview/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Gmail SMTP Settings](https://support.google.com/mail/answer/7126229)
