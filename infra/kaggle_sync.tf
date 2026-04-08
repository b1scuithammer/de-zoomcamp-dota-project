resource "google_project_service" "run" {
  project = var.project_id
  service = "run.googleapis.com"
}

resource "google_project_service" "cloud_scheduler" {
  project = var.project_id
  service = "cloudscheduler.googleapis.com"
}

resource "google_project_service" "secret_manager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
}

resource "google_project_service" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"
}

resource "google_project_service" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

data "google_project" "current" {}

resource "google_artifact_registry_repository" "kaggle_sync" {
  project       = var.project_id
  location      = var.region
  repository_id = "kaggle-sync"
  format        = "DOCKER"
}

resource "google_storage_bucket" "cloudbuild_source" {
  name                        = "${var.project_id}-cloudbuild-source"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "cloudbuild_source_reader" {
  bucket = google_storage_bucket.cloudbuild_source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

data "archive_file" "job_source" {
  type        = "zip"
  source_dir  = "${path.module}/${var.job_source_dir}"
  output_path = "${path.module}/job-source.zip"
}

resource "google_storage_bucket_object" "job_source" {
  name   = "job-source.zip"
  bucket = google_storage_bucket.cloudbuild_source.name
  source = data.archive_file.job_source.output_path
}

resource "google_project_iam_member" "cloudbuild_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

locals {
  cloud_run_image = var.cloud_run_image != "" ? var.cloud_run_image : "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.kaggle_sync.repository_id}/kaggle-sync-job:latest"
}

resource "null_resource" "build_job_image" {
  triggers = {
    source_hash = data.archive_file.job_source.output_sha
  }

  provisioner "local-exec" {
    command = "gcloud builds submit --tag ${local.cloud_run_image} ${data.archive_file.job_source.output_path} --project ${var.project_id} --region ${var.region}"
  }

  depends_on = [
    google_artifact_registry_repository.kaggle_sync,
    google_storage_bucket.cloudbuild_source,
    google_storage_bucket_object.job_source,
  ]
}

resource "google_service_account" "kaggle_sync" {
  account_id   = "kaggle-sync"
  display_name = "Kaggle GCS sync service account"
}

resource "google_storage_bucket_iam_member" "raw_data_writer" {
  bucket = google_storage_bucket.raw_data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.kaggle_sync.email}"
}

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

resource "google_secret_manager_secret_iam_member" "kaggle_username_accessor" {
  secret_id = google_secret_manager_secret.kaggle_username.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.kaggle_sync.email}"
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

resource "google_secret_manager_secret_iam_member" "kaggle_key_accessor" {
  secret_id = google_secret_manager_secret.kaggle_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.kaggle_sync.email}"
}

resource "google_cloud_run_v2_job" "kaggle_sync" {
  name     = "kaggle-sync-job"
  location = var.region

  depends_on = [null_resource.build_job_image]

  template {
    template {
      service_account = google_service_account.kaggle_sync.email

      containers {
        image = local.cloud_run_image

        env {
          name  = "KAGGLE_USERNAME"
          value = var.kaggle_username
        }

        env {
          name  = "KAGGLE_KEY"
          value = var.kaggle_key
        }

        env {
          name  = "KAGGLE_DATASET"
          value = var.kaggle_dataset
        }

        env {
          name  = "GCS_BUCKET"
          value = google_storage_bucket.raw_data.name
        }

        env {
          name  = "GCS_PREFIX"
          value = var.gcs_prefix
        }
      }
    }
  }
}

resource "google_cloud_run_v2_job_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.kaggle_sync.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.kaggle_sync.email}"
}

resource "google_cloud_scheduler_job" "kaggle_sync" {
  name        = "kaggle-sync-schedule"
  description = "Weekly schedule for the Kaggle GCS sync Cloud Run job."
  schedule    = var.scheduler_cron
  time_zone   = "UTC"

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.kaggle_sync.name}:run"
    headers = {
      "Content-Type" = "application/json"
    }
    body = base64encode("{}")

    oidc_token {
      service_account_email = google_service_account.kaggle_sync.email
    }
  }
}
