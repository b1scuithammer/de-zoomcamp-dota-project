output "bucket_name" {
  description = "The GCS bucket used for raw Kaggle data."
  value       = google_storage_bucket.raw_data.name
}

output "cloud_run_service_name" {
  description = "Cloud Run job created for Kaggle GCS sync."
  value       = google_cloud_run_v2_job.kaggle_sync.name
}

output "cloud_scheduler_job_name" {
  description = "Cloud Scheduler job that triggers the Cloud Run job."
  value       = google_cloud_scheduler_job.kaggle_sync.name
}

output "service_account_email" {
  description = "Service account used by Cloud Run and Cloud Scheduler."
  value       = google_service_account.kaggle_sync.email
}
