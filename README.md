# GitHub Issues Agent

## Quick Start

### Step 1: Set Python Version

```bash
uv python pin 3.12
```

### Step 2: Setup from Scratch (Best Practice)

After cleaning up, start fresh in the following order:

**1. Initialize environment and install dependencies**

Based on the existing `pyproject.toml`, run:

```bash
uv sync
```

This command will create the `.venv` directory and `uv.lock` file.

**2. Configure Python version**

Ensure the project uses Python 3.12:

```bash
uv python pin 3.12
```

**3. Configure environment variables**

Based on the existing `env.example`, create a new file:

```bash
cp env.example .env.dev
```

Then open `.env.dev` and fill in your API keys.

**4. Initialize Database**

Use Alembic to create the `issues` and `comments` tables:

```bash
uv run alembic upgrade head
```

**5. Run Agent in Development Mode**

Use the `langgraph.json` configuration file:

```bash
uv run langgraph dev --env .env.dev
```

## Project Overview

This is a cloud-native LangGraph agent application for processing GitHub issues. The project has been fully migrated to Google Cloud Platform (GCP) with complete DevSecOps/MLOps capabilities.

## Key Features

- **AI-Powered Issue Processing**: LangGraph-based agent for intelligent GitHub issue handling
- **Cloud-Native Architecture**: Deployed on GKE with full observability
- **DevSecOps Pipeline**: Automated CI/CD with security scanning at every stage
- **GitOps Deployment**: ArgoCD for declarative deployment management
- **Full Observability**: OpenTelemetry tracing, Prometheus metrics, Grafana dashboards

## Documentation

- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Complete production deployment instructions
- [Migration Summary](MIGRATION_SUMMARY.md) - GCP migration achievements and results
- [Infrastructure Guide](iac/terraform/README.md) - Terraform setup and configuration
- [Platform Tools](kubernetes/platform-tools/README.md) - Kubernetes platform installation
- [OpenTelemetry](docs/OPENTELEMETRY.md) - Observability implementation details
- [ELK Stack](elk/README.md) - Centralized logging with Elasticsearch, Kibana, Filebeat
- [Docker Images](docker/README.md) - Multi-variant Dockerfile comparison
- [CI/CD Pipelines](tekton/pipelines/README.md) - Tekton pipeline configuration
- [ArgoCD Setup](argocd/README.md) - GitOps deployment configuration
- [Monitoring & Alerts](alerts/README.md) - Prometheus alerts and Alertmanager

## Technology Stack

### Core Application
- **Python 3.11+**: Application runtime
- **FastAPI**: REST API framework
- **LangGraph**: Agent orchestration
- **PostgreSQL**: Relational database
- **Qdrant**: Vector database for embeddings

### Cloud Infrastructure (GCP)
- **GKE**: Kubernetes cluster management
- **Cloud SQL**: Managed PostgreSQL
- **Cloud NAT**: Network address translation
- **Secret Manager**: Secure credential storage
- **Artifact Registry**: Container image storage

### DevSecOps Tools
- **Terraform**: Infrastructure as Code
- **Helm**: Kubernetes package manager
- **Kustomize**: Kubernetes configuration management
- **Tekton**: Cloud-native CI/CD pipelines
- **ArgoCD**: GitOps continuous delivery
- **Harbor**: Container registry with vulnerability scanning
- **Trivy**: Security and vulnerability scanner
- **Checkov**: Infrastructure security scanning
- **SonarQube**: Code quality analysis

### Observability
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Jaeger**: Distributed tracing
- **OpenTelemetry**: Unified observability framework
- **Alertmanager**: Alert routing and management
- **ELK Stack**: Centralized logging (Elasticsearch, Kibana, Filebeat)

## Architecture

```
Internet → Nginx Ingress → FastAPI → LangGraph Agents
                                   ↓
                          PostgreSQL (Cloud SQL)
                                   ↓
                          Qdrant (Vector Store)
```

## Getting Started

### Local Development

1. **Install dependencies**:
   ```bash
   uv sync
   ```

2. **Configure environment**:
   ```bash
   cp env.example .env.dev
   # Edit .env.dev with your API keys
   ```

3. **Initialize database**:
   ```bash
   uv run alembic upgrade head
   ```

4. **Run development server**:
   ```bash
   uv run langgraph dev --env .env.dev
   ```

### Production Deployment

See the [Deployment Guide](DEPLOYMENT_GUIDE.md) for complete production deployment instructions on GCP.