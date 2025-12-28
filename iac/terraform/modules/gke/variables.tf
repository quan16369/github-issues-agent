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

variable "node_pool_config" {
  description = "Node pool configuration"
  type = object({
    machine_type   = string
    min_node_count = number
    max_node_count = number
    disk_size_gb   = number
    preemptible    = bool
  })
  default = {
    machine_type   = "e2-medium"
    min_node_count = 1
    max_node_count = 3
    disk_size_gb   = 20
    preemptible    = true
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
