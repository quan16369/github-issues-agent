# Staging Environment Configuration
project_id = "github-agent-staging"  # Replace with your GCP project ID
region     = "us-central1"
environment = "staging"

# Network Configuration
network_name = "github-agent-staging-vpc"

# GKE Configuration
cluster_name = "github-agent-staging-cluster"
gke_node_pool_config = {
  machine_type   = "e2-standard-2"
  min_node_count = 2
  max_node_count = 5
  disk_size_gb   = 30
  preemptible    = false
}

# Cloud SQL Configuration
db_instance_tier      = "db-custom-2-7680"
db_availability_type  = "ZONAL"
db_disk_size         = 20
db_name              = "github_issues_staging"
db_user              = "postgres"
# db_password should be set via environment variable: TF_VAR_db_password

# Secret Manager
secrets = {
  openai_api_key = "openai-api-key-staging"
  github_token   = "github-token-staging"
}

# Artifact Registry
artifact_registry_repos = ["agent-staging"]
