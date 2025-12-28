variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "VPC Network name"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
