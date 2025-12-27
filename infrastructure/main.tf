terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC Network
module "vpc" {
  source = "./modules/vpc"
  
  project_id   = var.project_id
  network_name = var.network_name
  region       = var.region
}

# Cloud SQL (PostgreSQL)
module "cloud_sql" {
  source = "./modules/cloud_sql"
  
  project_id     = var.project_id
  region         = var.region
  network_id     = module.vpc.network_id
  db_name        = var.db_name
  db_user        = var.db_user
  db_password    = var.db_password
}

# GKE Cluster
module "gke" {
  source = "./modules/gke"
  
  project_id     = var.project_id
  region         = var.region
  network_name   = module.vpc.network_name
  subnet_name    = module.vpc.subnet_name
  cluster_name   = var.cluster_name
}
