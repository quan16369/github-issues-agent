variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "network_name" {
  description = "VPC Network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "cluster_name" {
  description = "GKE Cluster name"
  type        = string
}
