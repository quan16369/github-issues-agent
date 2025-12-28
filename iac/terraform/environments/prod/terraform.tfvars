# Production Environment Configuration
project_id = "github-agent-prod"  # Replace with your GCP project ID
region     = "us-central1"
environment = "prod"

# Network Configuration
network_name = "github-agent-prod-vpc"

# GKE Configuration
cluster_name = "github-agent-prod-cluster"
gke_node_pool_config = {
  machine_type   = "e2-standard-4"
  min_node_count = 2
  max_node_count = 10
  disk_size_gb   = 50
  preemptible    = false
}

# Cloud SQL Configuration
db_instance_tier      = "db-custom-4-15360"
db_availability_type  = "REGIONAL"  # High Availability
db_disk_size         = 50
db_name              = "github_issues_prod"
db_user              = "postgres"
# db_password should be set via environment variable: TF_VAR_db_password

# Secret Manager
secrets = {
  openai_api_key = "openai-api-key-prod"
  github_token   = "github-token-prod"
}

# Artifact Registry
artifact_registry_repos = ["agent-prod"]
