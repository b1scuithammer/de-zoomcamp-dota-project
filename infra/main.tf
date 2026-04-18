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
  name          = "${var.project_id}-dota-raw-data"
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

resource "google_bigquery_dataset" "zoomcamp_dota_project" {
  dataset_id =                  "zoomcamp_dota_project"
  friendly_name =               "Zoomcamp Dota Project Dataset"
  location   =                  var.region
  delete_contents_on_destroy =  true
  
}

resource "google_service_account" "looker_studio" {
  account_id   = "looker-studio"
  display_name = "Looker Studio BigQuery access account"
}

resource "google_project_iam_member" "looker_studio_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.looker_studio.email}"
}

resource "google_bigquery_dataset_iam_member" "looker_studio_data_viewer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.looker_studio.email}"
}
