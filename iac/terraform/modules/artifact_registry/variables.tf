variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "repositories" {
  description = "List of repository names to create"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment name"
  type        = string
}
