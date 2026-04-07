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
