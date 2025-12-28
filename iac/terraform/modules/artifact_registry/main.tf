# Artifact Registry Repository
resource "google_artifact_registry_repository" "repos" {
  for_each = toset(var.repositories)
  
  project       = var.project_id
  location      = var.region
  repository_id = each.key
  description   = "Docker repository for ${each.key}"
  format        = "DOCKER"
  
  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
  
  docker_config {
    immutable_tags = false
  }
}

# IAM binding for GKE service account to pull images
resource "google_artifact_registry_repository_iam_member" "reader" {
  for_each = toset(var.repositories)
  
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.repos[each.key].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.project_id}.svc.id.goog[default/default]"
}
