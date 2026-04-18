from google.cloud import bigquery

def load_csv_to_bq(request):
    client = bigquery.Client()

    table_map = {
        "hero_names": "hero_names.csv",
        "match": "match.csv",
        "players": "players.csv",
        "player_ratings": "player_ratings.csv"
    }

    bucket = f"{client.project}-dota-raw-data"
    prefix = "raw/kaggle"

    for table, file in table_map.items():
        uri = f"gs://{bucket}/{prefix}/{file}"

        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,
            autodetect=True,
            write_disposition="WRITE_TRUNCATE",
        )

        table_id = f"{client.project}.zoomcamp_dota_project.{table}"
        job = client.load_table_from_uri(uri, table_id, job_config=job_config)
        job.result()

    return "Done"