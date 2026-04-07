###############################################################################
# variables.tf — add these to your existing variables or a new file
###############################################################################

variable "kaggle_username" {
  description = "Your Kaggle username"
  type        = string
  sensitive   = true
}

variable "kaggle_key" {
  description = "Your Kaggle API key"
  type        = string
  sensitive   = true
}

variable "kaggle_dataset" {
  description = "Kaggle dataset slug, e.g. username/dataset-name"
  type        = string
}

variable "gcs_prefix" {
  description = "Optional folder prefix inside the bucket, e.g. raw/kaggle"
  type        = string
  default     = "raw/kaggle"
}

variable "scheduler_cron" {
  description = "Cron expression for weekly schedule (default: Monday 02:00 UTC)"
  type        = string
  default     = "0 2 * * 1"
}

variable "cloud_run_image" {
  description = "Full image URI for the Cloud Run job, e.g. europe-west4-docker.pkg.dev/PROJECT/repo/kaggle-sync:latest"
  type        = string
}

variable "project_id" {
  description = "gcp project id"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}

###############################################################################
# locals — reference your existing bucket / project locals or vars here
###############################################################################

locals {
  # Replace these with your existing references if already defined
  project_id  = var.project_id   # assumed to exist in your config
  region      = var.region        # assumed to exist in your config
  bucket_name = google_storage_bucket.raw_data.name  # adjust to your bucket resource name
}

###############################################################################
# Service account for the Cloud Run job
###############################################################################

resource "google_service_account" "kaggle_sync" {
  account_id   = "kaggle-sync-sa"
  display_name = "Kaggle → GCS sync (Cloud Run Job)"
}

# Allow it to write to the existing bucket
resource "google_storage_bucket_iam_member" "kaggle_sync_writer" {
  bucket = local.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.kaggle_sync.email}"
}

###############################################################################
# Secret Manager — Kaggle credentials
###############################################################################

resource "google_secret_manager_secret" "kaggle_username" {
  secret_id = "kaggle-username"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "kaggle_username" {
  secret      = google_secret_manager_secret.kaggle_username.id
  secret_data = var.kaggle_username
}

resource "google_secret_manager_secret" "kaggle_key" {
  secret_id = "kaggle-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "kaggle_key" {
  secret      = google_secret_manager_secret.kaggle_key.id
  secret_data = var.kaggle_key
}

# Allow the service account to read both secrets
resource "google_secret_manager_secret_iam_member" "username_accessor" {
  secret_id = google_secret_manager_secret.kaggle_username.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.kaggle_sync.email}"
}

resource "google_secret_manager_secret_iam_member" "key_accessor" {
  secret_id = google_secret_manager_secret.kaggle_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.kaggle_sync.email}"
}

###############################################################################
# Cloud Run Job
###############################################################################

resource "google_cloud_run_v2_job" "kaggle_sync" {
  name     = "kaggle-sync"
  location = local.region

  template {
    template {
      service_account = google_service_account.kaggle_sync.email

      # Increase timeout/memory for large datasets if needed
      timeout = "3600s"

      containers {
        image = var.cloud_run_image

        env {
          name  = "KAGGLE_DATASET"
          value = var.kaggle_dataset
        }

        env {
          name  = "GCS_BUCKET"
          value = local.bucket_name
        }

        env {
          name  = "GCS_PREFIX"
          value = var.gcs_prefix
        }

        env {
          name = "KAGGLE_USERNAME"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.kaggle_username.secret_id
              version = "latest"
            }
          }
        }

        env {
          name = "KAGGLE_KEY"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.kaggle_key.secret_id
              version = "latest"
            }
          }
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }
    }
  }
}

###############################################################################
# Cloud Scheduler — triggers the job weekly
###############################################################################

# Service account for the scheduler to invoke Cloud Run
resource "google_service_account" "scheduler" {
  account_id   = "kaggle-sync-scheduler-sa"
  display_name = "Cloud Scheduler → Kaggle Sync invoker"
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  name     = google_cloud_run_v2_job.kaggle_sync.name
  location = local.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_scheduler_job" "kaggle_sync_weekly" {
  name      = "kaggle-sync-weekly"
  region    = local.region
  schedule  = var.scheduler_cron
  time_zone = "UTC"

  http_target {
    http_method = "POST"
    uri = "https://run.googleapis.com/v2/${google_cloud_run_v2_job.kaggle_sync.id}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}
