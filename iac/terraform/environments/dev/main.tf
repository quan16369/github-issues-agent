terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Uncomment for remote state storage
  # backend "gcs" {
  #   bucket = "github-agent-dev-terraform-state"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required GCP APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  project = var.project_id
  service = each.key

  disable_on_destroy = false
}

# VPC Network
module "vpc" {
  source = "../../modules/vpc"

  project_id   = var.project_id
  network_name = var.network_name
  region       = var.region
  environment  = var.environment

  depends_on = [google_project_service.required_apis]
}

# Cloud SQL (PostgreSQL)
module "cloud_sql" {
  source = "../../modules/cloud_sql"

  project_id           = var.project_id
  region               = var.region
  network_id           = module.vpc.network_id
  db_name              = var.db_name
  db_user              = var.db_user
  db_password          = var.db_password
  db_instance_tier     = var.db_instance_tier
  db_availability_type = var.db_availability_type
  db_disk_size         = var.db_disk_size
  environment          = var.environment

  depends_on = [module.vpc]
}

# GKE Cluster
module "gke" {
  source = "../../modules/gke"

  project_id       = var.project_id
  region           = var.region
  network_name     = module.vpc.network_name
  subnet_name      = module.vpc.subnet_name
  cluster_name     = var.cluster_name
  node_pool_config = var.gke_node_pool_config
  environment      = var.environment

  depends_on = [module.vpc]
}

# Secret Manager
module "secret_manager" {
  source = "../../modules/secret_manager"

  project_id  = var.project_id
  secrets     = var.secrets
  environment = var.environment

  depends_on = [google_project_service.required_apis]
}

# Artifact Registry
module "artifact_registry" {
  source = "../../modules/artifact_registry"

  project_id   = var.project_id
  region       = var.region
  repositories = var.artifact_registry_repos
  environment  = var.environment

  depends_on = [google_project_service.required_apis]
}
