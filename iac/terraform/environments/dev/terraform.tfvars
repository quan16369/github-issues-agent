# Development Environment Configuration
project_id  = "github-agent-dev" # Replace with your GCP project ID
region      = "us-central1"
environment = "dev"

# Network Configuration
network_name = "github-agent-dev-vpc"

# GKE Configuration
cluster_name = "github-agent-dev-cluster"
gke_node_pool_config = {
  machine_type   = "e2-medium"
  min_node_count = 1
  max_node_count = 3
  disk_size_gb   = 20
  preemptible    = true
}

# Cloud SQL Configuration
db_instance_tier     = "db-f1-micro"
db_availability_type = "ZONAL"
db_disk_size         = 10
db_name              = "github_issues_dev"
db_user              = "postgres"
# db_password should be set via environment variable: TF_VAR_db_password

# Secret Manager
secrets = {
  openai_api_key = "openai-api-key-dev"
  github_token   = "github-token-dev"
}

# Artifact Registry
artifact_registry_repos = ["agent-dev"]
