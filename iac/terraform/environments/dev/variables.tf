variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "network_name" {
  description = "VPC Network name"
  type        = string
}

variable "cluster_name" {
  description = "GKE Cluster name"
  type        = string
}

variable "gke_node_pool_config" {
  description = "GKE node pool configuration"
  type = object({
    machine_type   = string
    min_node_count = number
    max_node_count = number
    disk_size_gb   = number
    preemptible    = bool
  })
}

variable "db_name" {
  description = "Cloud SQL database name"
  type        = string
}

variable "db_user" {
  description = "Cloud SQL database user"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Cloud SQL database password"
  type        = string
  sensitive   = true
}

variable "db_instance_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_availability_type" {
  description = "Cloud SQL availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "ZONAL"
}

variable "db_disk_size" {
  description = "Cloud SQL disk size in GB"
  type        = number
  default     = 10
}

variable "secrets" {
  description = "Map of secret names to store in Secret Manager"
  type        = map(string)
  default     = {}
}

variable "artifact_registry_repos" {
  description = "List of Artifact Registry repository names"
  type        = list(string)
  default     = []
}
