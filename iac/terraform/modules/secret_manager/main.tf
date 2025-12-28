# Secret Manager Secrets
resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets
  
  project   = var.project_id
  secret_id = each.value
  
  replication {
    auto {}
  }
  
  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Optionally create secret versions (values should be provided manually or via CI/CD)
# Example: gcloud secrets versions add <secret-id> --data-file=<file>
