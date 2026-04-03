terraform {
  backend "gcs" {
    bucket = "dtc-de-course-484919-tf-state"
    prefix = "dota-project"
  }

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

resource "google_storage_bucket" "raw_data" {
  name          = "dota-project-raw-data"
  location      = var.region
  force_destroy = false

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
