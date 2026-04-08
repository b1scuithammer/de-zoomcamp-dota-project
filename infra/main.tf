terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("${path.module}/creds/terraform-creds.json")
}

resource "google_storage_bucket" "raw_data" {
  name          = "dota-project-raw-data"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 90  # days — adjust or remove if you want to keep data indefinitely
    }
    action {
      type = "Delete"
    }
  }
}
