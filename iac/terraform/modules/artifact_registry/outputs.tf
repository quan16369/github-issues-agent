output "repository_ids" {
  description = "Map of repository names to IDs"
  value       = { for k, v in google_artifact_registry_repository.repos : k => v.id }
}

output "repository_urls" {
  description = "Map of repository names to full URLs"
  value = {
    for k, v in google_artifact_registry_repository.repos :
    k => "${v.location}-docker.pkg.dev/${v.project}/${v.repository_id}"
  }
}
