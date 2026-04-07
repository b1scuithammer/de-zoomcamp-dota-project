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

variable "gcs_prefix" {
  description = "Folder prefix inside the bucket"
  type        = string
  default     = "raw/kaggle"
}
