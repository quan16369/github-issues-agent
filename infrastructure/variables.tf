variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "VPC Network name"
  type        = string
  default     = "github-issue-agent-vpc"
}

variable "db_name" {
  description = "Cloud SQL database name"
  type        = string
  default     = "github_issues"
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

variable "cluster_name" {
  description = "GKE Cluster name"
  type        = string
  default     = "github-issue-agent-cluster"
}
