# de-zoomcamp-dota-project
This project aims to investigate the relation between the pick rate and win rate of certain heroes in DOTA. The project uses terraform to create Google Cloud resources, which download a Kaggle dataset into a Google Cloud bucket, load this dataset into Bigquery and Transforms the data into the correct format.

## Setup

### Prerequisites
- A Google Cloud Platform (GCP) project with billing enabled
- Terraform installed (version ~> 1.0)
- Google Cloud SDK (`gcloud`) installed and authenticated
- A Kaggle account with API access (get your username and API key from [Kaggle Account Settings](https://www.kaggle.com/account))

### Steps
1. **Clone the repository:**
   ```bash
   git clone https://github.com/b1scuithammer/de-zoomcamp-dota-project.git
   cd de-zoomcamp-dota-project
   ```

2. **Set up GCP credentials:**
   - Create a service account in your GCP project with the following roles:
     - `roles/storage.admin`
     - `roles/bigquery.admin`
     - `roles/cloudfunctions.admin`
     - `roles/run.admin`
     - `roles/cloudscheduler.admin`
     - `roles/secretmanager.admin`
     - `roles/artifactregistry.admin`
     - `roles/cloudbuild.builds.editor`
   - Download the service account key as JSON and save it as `infra/creds/terraform-creds.json`

3. **Configure Terraform variables:**
   - Copy the example variables file:
     ```bash
     cp infra/terraform.tfvars.example infra/terraform.tfvars
     ```
   - Edit `infra/terraform.tfvars` and fill in your values:
     - `project_id`: Your GCP project ID
     - `kaggle_username`: Your Kaggle username
     - `kaggle_key`: Your Kaggle API key
     - `kaggle_dataset`: The Kaggle dataset slug (e.g., `username/dataset-name`)

4. **Deploy the infrastructure:**
   ```bash
   cd infra
   terraform init
   terraform plan
   terraform apply
   ```

This will create all necessary GCP resources including:
- Google Cloud Storage bucket for raw data
- BigQuery dataset and tables
- Cloud Run job for downloading Kaggle data
- Cloud Function for loading data to BigQuery
- Scheduled jobs for automated data processing

The pipeline will run automatically:
- Kaggle data download: Every Monday at 02:00 UTC
- Data loading to BigQuery: Every Monday at 02:30 UTC (Europe/Amsterdam)
- Data transformations: Every Monday at 03:00 UTC 