# de-zoomcamp-dota-project

# kaggle-gcs-sync

A weekly pipeline that downloads a Kaggle dataset into a GCS bucket, running as a Cloud Run Job triggered by Cloud Scheduler.

## Repository structure

```
kaggle-gcs-sync/
├── infra/                  # Terraform configuration
│   ├── main.tf             # Your existing GCS bucket config
│   ├── kaggle_sync.tf      # Cloud Run, Scheduler, IAM, Secrets
│   ├── variables.tf        # All variable declarations
│   ├── outputs.tf          # (optional) useful outputs
│   └── terraform.tfvars    # !! NOT committed — see .gitignore
│
├── job/                    # Cloud Run job source
│   ├── download_to_gcs.py
│   ├── Dockerfile
│   └── requirements.txt
│
├── .gitignore
└── README.md
```

## Setup

See the [configuration guide](#) for step-by-step instructions on:
1. Enabling GCP APIs
2. Building and pushing the Docker image
3. Providing Kaggle credentials via Secret Manager
4. Running `terraform apply`
5. Verifying with a manual job execution