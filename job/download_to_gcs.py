#!/usr/bin/env python3
import os
import zipfile
import tempfile
from pathlib import Path
import kaggle
from google.cloud import storage


def download_dataset(dataset_slug: str, download_dir: Path) -> list:
    print(f"Downloading dataset: {dataset_slug}")
    kaggle.api.authenticate()
    kaggle.api.dataset_download_files(dataset_slug, path=str(download_dir), unzip=False)

    for item in list(download_dir.iterdir()):
        if item.suffix == ".zip":
            print(f"Unzipping {item.name}")
            with zipfile.ZipFile(item, "r") as zf:
                zf.extractall(download_dir)
            item.unlink()

    return list(download_dir.iterdir())


def upload_to_gcs(local_files: list, bucket_name: str, prefix: str) -> None:
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
