FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY download_to_gcs.py .

# Kaggle API reads credentials from these env vars (injected by Cloud Run from Secret Manager)
ENV KAGGLE_USERNAME=""
ENV KAGGLE_KEY=""

CMD ["python", "download_to_gcs.py"]
