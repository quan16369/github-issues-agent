output "network_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.vpc.subnet_name
}

output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.cloud_sql.connection_name
}

output "database_ip" {
  description = "Cloud SQL private IP address"
  value       = module.cloud_sql.private_ip_address
}

output "gke_cluster_name" {
  description = "GKE Cluster name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE Cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "get_credentials_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}
