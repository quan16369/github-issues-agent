# Private IP allocation for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
  project       = var.project_id
}

# Private VPC connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Cloud SQL Instance (PostgreSQL)
resource "google_sql_database_instance" "postgres" {
  name             = "github-issue-postgres-${random_id.db_suffix.hex}"
  database_version = "POSTGRES_16"
  region           = var.region
  project          = var.project_id
  
  depends_on = [google_service_networking_connection.private_vpc_connection]
  
  settings {
    tier              = var.db_instance_tier
    availability_type = var.db_availability_type
    disk_size         = var.db_disk_size
    disk_type         = "PD_SSD"
    
    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      point_in_time_recovery_enabled = true
    }
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    
    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }
  
  deletion_protection = false  # Set to true for production
}

# Random suffix for unique naming
resource "random_id" "db_suffix" {
  byte_length = 4
}

# Database
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

# Database user
resource "google_sql_user" "user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
  project  = var.project_id
}
