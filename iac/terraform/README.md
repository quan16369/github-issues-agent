# Terraform Infrastructure for GitHub Issue Agent

This directory contains Terraform configurations for deploying the GitHub Issue Agent infrastructure on Google Cloud Platform (GCP).

## Directory Structure

```
iac/terraform/
├── modules/              # Reusable Terraform modules
│   ├── vpc/             # VPC network with subnets and Cloud NAT
│   ├── cloud_sql/       # Cloud SQL PostgreSQL with private access
│   ├── gke/             # GKE cluster with configurable node pools
│   ├── secret_manager/  # Secret Manager for sensitive data
│   └── artifact_registry/ # Docker image registry
└── environments/         # Environment-specific configurations
    ├── dev/             # Development environment
    ├── staging/         # Staging environment
    └── prod/            # Production environment
```

## Prerequisites

1. **Install Terraform** (>= 1.5)
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Install gcloud CLI**
   ```bash
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   ```

3. **Authenticate with GCP**
   ```bash
   gcloud auth application-default login
   ```

4. **Create GCP Projects** (one per environment)
   ```bash
   gcloud projects create github-agent-dev --name="GitHub Agent Dev"
   gcloud projects create github-agent-staging --name="GitHub Agent Staging"
   gcloud projects create github-agent-prod --name="GitHub Agent Prod"
   ```

5. **Enable Billing** for each project via GCP Console

## Deployment Steps

### 1. Configure Variables

Edit the appropriate `terraform.tfvars` file in each environment directory:

```bash
# For development
cd environments/dev
cp terraform.tfvars terraform.tfvars.local
# Edit terraform.tfvars.local with your values
```

**Required variables:**
- `project_id`: Your GCP project ID
- `region`: GCP region (default: us-central1)
- `db_password`: Database password (use environment variable)

### 2. Set Sensitive Variables

```bash
export TF_VAR_db_password="your-secure-password"
```

### 3. Initialize Terraform

```bash
cd environments/dev
terraform init
```

### 4. Review Plan

```bash
terraform plan
```

### 5. Apply Configuration

```bash
terraform apply
```

### 6. Configure kubectl

```bash
gcloud container clusters get-credentials github-agent-dev-cluster \
  --region us-central1 \
  --project github-agent-dev
```

## Module Details

### VPC Module
- Creates custom VPC network
- Configures private subnets with secondary IP ranges for GKE pods/services
- Sets up Cloud NAT for outbound internet access
- Configures firewall rules

### Cloud SQL Module
- PostgreSQL 16 with private IP
- Automated backups and point-in-time recovery
- Private Service Connect integration
- Configurable instance tier and disk size

### GKE Module
- Private GKE cluster
- Workload Identity enabled
- Network policy enabled
- Configurable node pools (machine type, autoscaling, preemptible)
- Maintenance windows configured

### Secret Manager Module
- Stores sensitive API keys (OpenAI, GitHub)
- Auto-replication across regions
- IAM integration for GKE workloads

### Artifact Registry Module
- Docker image repositories
- Environment-specific projects
- IAM roles for GKE to pull images

## Environment Configurations

### Development
- **Machine Type**: e2-medium
- **Nodes**: 1-3 (preemptible)
- **Database**: db-f1-micro (ZONAL)
- **Cost**: ~$50-100/month

### Staging
- **Machine Type**: e2-standard-2
- **Nodes**: 2-5
- **Database**: db-custom-2-7680 (ZONAL)
- **Cost**: ~$150-300/month

### Production
- **Machine Type**: e2-standard-4
- **Nodes**: 2-10
- **Database**: db-custom-4-15360 (REGIONAL HA)
- **Cost**: ~$500-1000/month

## Security Best Practices

1. **Run Checkov scans** before applying
   ```bash
   checkov -d . --framework terraform
   ```

2. **Use Secret Manager** for all sensitive data

3. **Enable Cloud Armor** for DDoS protection (add to load balancer)

4. **Configure VPC Service Controls** for data exfiltration prevention

5. **Enable Audit Logging**
   ```bash
   gcloud logging sinks create terraform-audit \
     storage.googleapis.com/your-audit-bucket \
     --log-filter='protoPayload.methodName="terraform"'
   ```

## Remote State Storage

Uncomment backend configuration in `main.tf`:

```bash
# Create GCS bucket for state
gsutil mb -p github-agent-dev gs://github-agent-dev-terraform-state
gsutil versioning set on gs://github-agent-dev-terraform-state
```

## Cleanup

To destroy infrastructure:

```bash
cd environments/dev
terraform destroy
```

## Troubleshooting

### API Not Enabled Error
```bash
gcloud services enable <api-name>.googleapis.com --project=<project-id>
```

### Quota Exceeded
Request quota increase in GCP Console → IAM & Admin → Quotas

### Authentication Issues
```bash
gcloud auth application-default login
gcloud config set project <project-id>
```

## Cost Optimization Tips

1. Use **preemptible nodes** in dev/staging
2. Enable **GKE cluster autoscaling**
3. Use **committed use discounts** for production
4. Set up **budget alerts** in GCP Console
5. Use **Cloud SQL read replicas** only when needed

## Next Steps

After infrastructure deployment:
1. Install platform tools (Harbor, Tekton, ArgoCD) - see `../../../kubernetes/`
2. Deploy application using Helm - see `../../../helm_charts/`
3. Configure GitOps with ArgoCD - see `../../../k8s/`
