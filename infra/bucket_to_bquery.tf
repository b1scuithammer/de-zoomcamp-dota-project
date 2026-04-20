data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../function"
  output_path = "${path.module}/function.zip"
}

resource "google_project_service" "cloudfunctions" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
}

resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-function-source"
  location = "EU"
}

resource "google_storage_bucket_object" "function_archive" {
  name   = "function-${data.archive_file.function_zip.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_zip.output_path
}

resource "google_cloudfunctions2_function" "bq_loader" {
  name     = "bq-csv-loader"
  location = var.region
  depends_on = [google_project_service.cloudfunctions]

  build_config {
    runtime     = "python311"
    entry_point = "load_csv_to_bq"

    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_archive.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "512M"
    timeout_seconds    = 300

    ingress_settings = "ALLOW_ALL"
  }
}

resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = google_cloudfunctions2_function.bq_loader.location
  service  = google_cloudfunctions2_function.bq_loader.name

  role   = "roles/run.invoker"
  member = "allUsers"
}

resource "google_cloud_scheduler_job" "daily_load" {
  name      = "bq-daily-load"
  schedule  = "30 2 * * *"
  time_zone = "Europe/Amsterdam"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.bq_loader.service_config[0].uri
  }
}