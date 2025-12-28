# OpenTelemetry & Observability Setup

Complete OpenTelemetry instrumentation for distributed tracing and metrics collection.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                     Application Layer                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐│
│  │  FastAPI   │  │  Agents    │  │ Guardrails │  │  Qdrant    ││
│  │            │  │  (5 nodes) │  │            │  │  Search    ││
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘│
│        │                │                │                │       │
│        └────────────────┴────────────────┴────────────────┘       │
│                           ↓                                       │
│              ┌────────────────────────┐                           │
│              │ OpenTelemetry SDK      │                           │
│              │  - Traces (spans)      │                           │
│              │  - Metrics (counters)  │                           │
│              └───────────┬────────────┘                           │
└──────────────────────────┼────────────────────────────────────────┘
                           ↓
                ┌──────────────────────┐
                │ OpenTelemetry        │
                │ Collector            │
                │  - Receive (OTLP)    │
                │  - Process           │
                │  - Export            │
                └────┬────────┬────────┘
                     │        │
            ┌────────┘        └────────┐
            ↓                          ↓
   ┌────────────────┐         ┌────────────────┐
   │    Jaeger      │         │  Prometheus    │
   │  (Tracing UI)  │         │  (Metrics DB)  │
   └────────────────┘         └────────┬───────┘
                                       ↓
                              ┌────────────────┐
                              │    Grafana     │
                              │  (Dashboards)  │
                              └────────────────┘
```

## Components Added

### 1. Dependencies (`pyproject.toml`)

```toml
# OpenTelemetry for observability
"opentelemetry-api>=1.21.0",
"opentelemetry-sdk>=1.21.0",
"opentelemetry-instrumentation-fastapi>=0.42b0",
"opentelemetry-instrumentation-requests>=0.42b0",
"opentelemetry-instrumentation-sqlalchemy>=0.42b0",
"opentelemetry-exporter-otlp-proto-grpc>=1.21.0",
"opentelemetry-exporter-prometheus>=0.42b0",
"prometheus-client>=0.19.0",
```

### 2. Telemetry Module (`src/utils/telemetry.py`)

**Features:**
- Setup tracing with OTLP exporter → Jaeger
- Setup metrics with Prometheus exporter
- Auto-instrumentation for FastAPI, Requests, SQLAlchemy
- Custom application metrics:
  - `issues_processed_total` - Counter
  - `issues_failed_total` - Counter
  - `issue_processing_duration_seconds` - Histogram
  - `agent_executions_total` - Counter by agent name
  - `agent_execution_duration_seconds` - Histogram by agent
  - `openai_tokens_consumed_total` - Counter
  - `openai_requests_total` - Counter
  - `guardrail_blocks_total` - Counter by type
  - `vector_searches_total` - Counter
  - `vector_search_duration_seconds` - Histogram

**Configuration:**
```python
from src.utils.telemetry import initialize_telemetry

tracer, meter, app_metrics = initialize_telemetry(
    service_name="github-issue-agent",
    service_version="1.0.0",
    environment="production",
    otlp_endpoint="http://otel-collector:4317",
    enable_prometheus=True,
    prometheus_port=8001,
)
```

### 3. Agent Tracing (`src/utils/traced_agents.py`)

Decorator `@trace_agent(name)` adds:
- Span creation for each agent execution
- Duration tracking
- Error recording with exception details
- Metrics recording (counter + histogram)
- Guardrail block detection

**Usage:**
```python
@trace_agent("input_guardrail")
async def input_guardrail_agent(state: IssueState) -> dict:
    # Agent logic...
    return {"blocked": False}
```

### 4. API Integration (`src/api/main.py`)

- Initialize telemetry on startup
- Instrument FastAPI app automatically
- Track issue processing metrics
- Record failures with error types

## Configuration

### Environment Variables

```bash
# OpenTelemetry Collector endpoint
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317

# Service metadata
SERVICE_VERSION=1.0.0
ENVIRONMENT=production

# Prometheus metrics port (exposed on container)
PROMETHEUS_PORT=8001
```

### Kubernetes Deployment

Update [helm_charts/github-agent/values.yaml](../../helm_charts/github-agent/values.yaml):

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.observability:4317"
  - name: SERVICE_VERSION
    value: "{{ .Chart.AppVersion }}"
  - name: ENVIRONMENT
    value: "{{ .Values.environment }}"

# Expose Prometheus metrics port
service:
  type: ClusterIP
  port: 8000
  metricsPort: 8001  # Prometheus scrape endpoint
```

Add metrics port to deployment:

```yaml
ports:
  - name: http
    containerPort: 8000
    protocol: TCP
  - name: metrics
    containerPort: 8001
    protocol: TCP
```

## Instrumented Components

### 1. FastAPI Endpoints

**Automatic spans:**
- `GET /health`
- `GET /ready`
- `POST /process-issue`
- `POST /validate`

**Attributes:**
- `http.method`
- `http.url`
- `http.status_code`
- `http.route`

### 2. Agent Nodes

**Manual spans for each agent:**
- `agent.input_guardrail` - Input validation
- `agent.issue_search` - Vector search
- `agent.classification` - Issue classification
- `agent.recommendation` - Generate recommendations
- `agent.output_guardrail` - Output validation

**Span attributes:**
- `agent.name` - Agent identifier
- `agent.duration_seconds` - Execution time
- `agent.status` - success/error
- `agent.blocked` - Boolean if guardrail blocked
- `issue.title` - Truncated title
- `issue.body_length` - Body character count
- `error.type` - Exception class name (on error)
- `error.message` - Error message (on error)

### 3. Metrics Collected

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `issues_processed_total` | Counter | `status=success` | Total issues processed |
| `issues_failed_total` | Counter | `error_type=<name>` | Total failed issues |
| `issue_processing_duration_seconds` | Histogram | - | End-to-end processing time |
| `agent_executions_total` | Counter | `agent=<name>`, `status=success/error` | Agent invocations |
| `agent_execution_duration_seconds` | Histogram | `agent=<name>` | Per-agent execution time |
| `guardrail_blocks_total` | Counter | `agent=<name>` | Guardrail blocks by agent |
| `openai_tokens_consumed_total` | Counter | `model=<name>` | OpenAI token usage |
| `vector_searches_total` | Counter | - | Qdrant searches |
| `vector_search_duration_seconds` | Histogram | - | Search latency |

## Viewing Traces in Jaeger

### Access Jaeger UI

```bash
# Port-forward Jaeger query service
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# Open in browser
open http://localhost:16686
```

### Finding Traces

1. **Service:** Select `github-issue-agent`
2. **Operation:** Select operation to filter:
   - `POST /process-issue` - Full workflow
   - `agent.input_guardrail` - Specific agent
3. **Tags:** Add filters:
   - `agent.blocked=true` - Only blocked requests
   - `error=true` - Only failed traces
   - `http.status_code=500` - Server errors

### Example Trace Timeline

```
POST /process-issue (350ms)
├─ agent.input_guardrail (45ms)
│  ├─ check_jailbreak (15ms)
│  ├─ check_toxicity (20ms)
│  └─ check_secrets (10ms)
├─ agent.issue_search (120ms)
│  └─ qdrant_search (115ms)
├─ agent.classification (80ms)
│  └─ openai_api_call (75ms)
├─ agent.recommendation (90ms)
│  └─ openai_api_call (85ms)
└─ agent.output_guardrail (15ms)
   ├─ check_toxicity (8ms)
   └─ check_secrets (7ms)
```

## Prometheus Metrics

### Scraping Configuration

The observability stack automatically scrapes metrics from `http://<pod-ip>:8001/metrics`.

ServiceMonitor:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: github-agent-metrics
  namespace: default
spec:
  selector:
    matchLabels:
      app: github-agent
  endpoints:
    - port: metrics
      interval: 15s
      path: /metrics
```

### Available Metrics Endpoint

```bash
# Check metrics locally
curl http://localhost:8001/metrics

# In Kubernetes
kubectl port-forward svc/github-agent 8001:8001
curl http://localhost:8001/metrics
```

## Custom Metrics Usage

### In Application Code

```python
from src.utils.telemetry import get_app_metrics

app_metrics = get_app_metrics()

# Count OpenAI tokens
app_metrics.openai_tokens_counter.add(
    response.usage.total_tokens,
    {"model": "gpt-4"}
)

# Track vector search
import time
start = time.time()
results = await qdrant_store.search(query)
duration = time.time() - start

app_metrics.vector_search_counter.add(1)
app_metrics.vector_search_duration.record(duration)
```

## Testing Telemetry

### 1. Check Prometheus Metrics

```bash
# Send test request
curl -X POST http://localhost:8000/process-issue \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Issue","body":"Test content"}'

# Check metrics
curl http://localhost:8001/metrics | grep issues_processed
```

Expected output:
```
# HELP issues_processed_total Total number of issues processed
# TYPE issues_processed_total counter
issues_processed_total{status="success"} 1.0

# HELP issue_processing_duration_seconds Time taken to process an issue
# TYPE issue_processing_duration_seconds histogram
issue_processing_duration_seconds_bucket{le="0.1"} 0.0
issue_processing_duration_seconds_bucket{le="0.5"} 1.0
issue_processing_duration_seconds_sum 0.352
issue_processing_duration_seconds_count 1.0
```

### 2. View Traces in Jaeger

1. Send multiple requests with different inputs
2. Open Jaeger UI
3. Filter by service `github-issue-agent`
4. View trace details with timing breakdown

### 3. Query Prometheus

```bash
# PromQL queries
kubectl port-forward -n observability svc/prometheus 9090:9090

# Open Prometheus UI
open http://localhost:9090
```

**Example queries:**
```promql
# Request rate
rate(issues_processed_total[5m])

# Average latency
rate(issue_processing_duration_seconds_sum[5m]) / rate(issue_processing_duration_seconds_count[5m])

# Error rate
rate(issues_failed_total[5m])

# Agent execution time (95th percentile)
histogram_quantile(0.95, rate(agent_execution_duration_seconds_bucket[5m]))

# Guardrail block rate
rate(guardrail_blocks_total[5m])
```

## Grafana Dashboards

See [grafana/](../grafana/) directory for pre-built dashboards:

1. **FastAPI Overview** - Request rates, latency, error rates
2. **Agent Performance** - Per-agent execution times, success rates
3. **OpenAI Usage** - Token consumption, costs
4. **Guardrails** - Block rates by type
5. **Vector Search** - Search latency, result quality

## Troubleshooting

### No Traces Appearing in Jaeger

```bash
# Check OTLP collector is reachable
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://otel-collector.observability:4317

# Check collector logs
kubectl logs -n observability -l app=otel-collector

# Verify service mesh doesn't block OTLP traffic
```

### Prometheus Not Scraping Metrics

```bash
# Check ServiceMonitor exists
kubectl get servicemonitor -A

# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus 9090:9090
# Open http://localhost:9090/targets

# Verify metrics port is exposed
kubectl get svc github-agent -o yaml
```

### High Cardinality Warnings

If you see too many unique metric label combinations:

```python
# Limit label cardinality
# DON'T: Use user input as label
app_metrics.counter.add(1, {"issue_title": state.title})

# DO: Use categorical labels
app_metrics.counter.add(1, {"agent": "classification", "status": "success"})
```

## Performance Impact

- **Tracing overhead:** ~1-3% latency increase
- **Metrics overhead:** Negligible (<0.1%)
- **Memory:** ~10-20MB per service instance
- **Network:** ~1-5KB per request to OTLP collector

To disable in development:
```bash
# Don't initialize telemetry
OTEL_EXPORTER_OTLP_ENDPOINT=""
```

## Next Steps

1. OpenTelemetry instrumentation added
2. Create Grafana dashboards (Task 24)
3. Configure alerts (Task 25)
4. Set up SLOs and error budgets
5. Add custom business metrics

## References

- [OpenTelemetry Python Docs](https://opentelemetry.io/docs/instrumentation/python/)
- [FastAPI Instrumentation](https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/fastapi/fastapi.html)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
