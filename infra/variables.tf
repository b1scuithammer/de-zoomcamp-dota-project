variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west4"
}

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

variable "cloud_run_image" {
  description = "Container image for the Cloud Run job"
  type        = string
}

variable "scheduler_cron" {
  description = "Cron schedule for the Cloud Scheduler job"
  type        = string
  default     = "0 2 * * 1"
}

variable "gcs_prefix" {
  description = "Folder prefix inside the bucket"
  type        = string
  default     = "raw/kaggle"
}

variable "job_source_dir" {
  description = "Relative path to the job source directory from infra/"
  type        = string
  default     = "../job"
}
