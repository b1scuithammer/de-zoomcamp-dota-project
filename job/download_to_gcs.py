import os
import tempfile
import zipfile
from pathlib import Path
from kaggle.api.kaggle_api_extended import KaggleApi
from google.cloud import storage


def main():
    dataset_slug = os.environ["KAGGLE_DATASET"]
    bucket_name = os.environ["GCS_BUCKET"]
    prefix = os.environ.get("GCS_PREFIX", "").strip("/")

    print(f"Downloading Kaggle dataset: {dataset_slug}")

    api = KaggleApi()
    api.authenticate()

    with tempfile.TemporaryDirectory() as tmpdir:
        download_dir = Path(tmpdir)
        api.dataset_download_files(dataset_slug, path=str(download_dir), unzip=False)

        for zip_path in download_dir.glob("*.zip"):
            print(f"Unzipping {zip_path.name}")
            with zipfile.ZipFile(zip_path, "r") as zf:
                zf.extractall(download_dir)
            zip_path.unlink()

        client = storage.Client()
        bucket = client.bucket(bucket_name)

        for file_path in download_dir.rglob("*"):
            if not file_path.is_file():
                continue
            object_name = file_path.relative_to(download_dir).as_posix()
            blob_name = f"{prefix}/{object_name}" if prefix else object_name
            print(f"Uploading {file_path.name} -> gs://{bucket_name}/{blob_name}")
            bucket.blob(blob_name).upload_from_filename(str(file_path))

    print("Upload complete.")


if __name__ == "__main__":
    main()
