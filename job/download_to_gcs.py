#!/usr/bin/env python3
"""
Downloads a Kaggle dataset and uploads it to a GCS bucket.
Expects the following environment variables:
  - KAGGLE_DATASET   : Dataset slug, e.g. "username/dataset-name"
  - GCS_BUCKET       : GCS bucket name (without gs:// prefix)
  - GCS_PREFIX       : (optional) folder prefix inside the bucket, e.g. "raw/kaggle"
  - KAGGLE_USERNAME  : Injected from Secret Manager via Cloud Run
  - KAGGLE_KEY       : Injected from Secret Manager via Cloud Run
"""

import os
import shutil
import tempfile
import zipfile
from pathlib import Path

from google.cloud import storage
from kaggle.api.kaggle_api_extended import KaggleApiExtended


def download_dataset(dataset_slug: str, download_dir: Path) -> list[Path]:
    """Download a Kaggle dataset and return a list of extracted file paths."""
    api = KaggleApiExtended()
    api.authenticate()

    print(f"Downloading dataset: {dataset_slug}")
    api.dataset_download_files(dataset_slug, path=str(download_dir), unzip=False)

    # Unzip any zip archives
    files = []
    for item in download_dir.iterdir():
        if item.suffix == ".zip":
            print(f"Unzipping {item.name}")
            with zipfile.ZipFile(item, "r") as zf:
                zf.extractall(download_dir)
            item.unlink()
        else:
            files.append(item)

    return list(download_dir.iterdir())


def upload_to_gcs(local_files: list[Path], bucket_name: str, prefix: str) -> None:
    """Upload local files to a GCS bucket under the given prefix."""
    client = storage.Client()
    bucket = client.bucket(bucket_name)

    for file_path in local_files:
        if not file_path.is_file():
            continue
        blob_name = f"{prefix}/{file_path.name}" if prefix else file_path.name
        blob = bucket.blob(blob_name)
        print(f"Uploading {file_path.name} -> gs://{bucket_name}/{blob_name}")
        blob.upload_from_filename(str(file_path))

    print("Upload complete.")


def main():
    dataset_slug = os.environ["KAGGLE_DATASET"]
    bucket_name = os.environ["GCS_BUCKET"]
    prefix = os.environ.get("GCS_PREFIX", "").strip("/")

    with tempfile.TemporaryDirectory() as tmpdir:
        download_dir = Path(tmpdir)
        files = download_dataset(dataset_slug, download_dir)
        upload_to_gcs(files, bucket_name, prefix)


if __name__ == "__main__":
    main()
