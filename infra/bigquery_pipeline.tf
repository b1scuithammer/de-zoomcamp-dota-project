resource "google_bigquery_data_transfer_config" "stg_player_hero_wins" {
  display_name           = "dota hero win rates pipeline"
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  location               = var.region
  schedule               = "every day 03:00"

  params = {
    query = <<-SQL
      CREATE OR REPLACE TABLE `${var.project_id}.zoomcamp_dota_project.stg_player_hero_wins`
      CLUSTER BY hero_id, account_id AS
      SELECT
        m.match_id AS match_id,
        p.hero_id AS hero_id,
        p.account_id AS account_id,
        CASE
          WHEN (p.player_slot < 128 AND m.radiant_win = TRUE)
            OR (p.player_slot >= 128 AND m.radiant_win = FALSE)
          THEN 1
          ELSE 0
        END AS is_win
      FROM
        `${var.project_id}.zoomcamp_dota_project.match` AS m
      JOIN
        `${var.project_id}.zoomcamp_dota_project.players` AS p
        ON m.match_id = p.match_id
    SQL
  }
}

resource "google_bigquery_data_transfer_config" "total_matches_view" {
  display_name           = "total matches view"
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  location               = var.region
  schedule               = "every day 03:00"

  params = {
    query = <<-SQL
      CREATE OR REPLACE VIEW `${var.project_id}.zoomcamp_dota_project.total_matches_view` AS
      SELECT
        COUNT(DISTINCT match_id) AS total_matches
      FROM
        `${var.project_id}.zoomcamp_dota_project.match`
    SQL
  }
}

resource "google_bigquery_data_transfer_config" "stg_high_skill_player" {
  display_name           = "high skill players staging table"
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  location               = var.region
  schedule               = "every day 03:05"

  params = {
    query = <<-SQL
      CREATE OR REPLACE TABLE `${var.project_id}.zoomcamp_dota_project.stg_high_skill_player` AS
      WITH ranked_players AS (
        SELECT
          account_id,
          NTILE(3) OVER (ORDER BY trueskill_mu DESC) AS skill_tier
        FROM
          `${var.project_id}.zoomcamp_dota_project.player_ratings`
        WHERE
          total_matches >= 10
          AND account_id != 0
      )
      SELECT
        account_id
      FROM
        ranked_players
      WHERE
        skill_tier = 1
    SQL
  }
}

resource "google_bigquery_data_transfer_config" "stg_low_skill_player" {
  display_name           = "low skill players staging table"
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  location               = var.region
  schedule               = "every day 03:05"

  params = {
    query = <<-SQL
      CREATE OR REPLACE TABLE `${var.project_id}.zoomcamp_dota_project.stg_low_skill_player` AS
      WITH ranked_players AS (
        SELECT
          account_id,
          NTILE(3) OVER (ORDER BY trueskill_mu ASC) AS skill_tier
        FROM
          `${var.project_id}.zoomcamp_dota_project.player_ratings`
        WHERE
          total_matches >= 10
          AND account_id != 0
      )
      SELECT
        account_id
      FROM
        ranked_players
      WHERE
        skill_tier = 1
    SQL
  }
}

resource "google_bigquery_data_transfer_config" "hero_pick_and_win_rates" {
  display_name           = "hero pick and win rates"
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  location               = var.region
  schedule               = "every day 03:10"

  depends_on = [
    google_bigquery_data_transfer_config.stg_player_hero_wins,
    google_bigquery_data_transfer_config.total_matches_view,
  ]

  params = {
    query = <<-SQL
      CREATE OR REPLACE TABLE `${var.project_id}.zoomcamp_dota_project.hero_pick_and_win_rates` AS
      SELECT
        h.localized_name,
        COUNT(s.match_id) / tm.total_matches AS pick_rate,
        SUM(s.is_win) / COUNT(s.match_id) AS win_rate
      FROM
        `${var.project_id}.zoomcamp_dota_project.stg_player_hero_wins` AS s
      JOIN
        `${var.project_id}.zoomcamp_dota_project.hero_names` AS h
        ON s.hero_id = h.hero_id
      CROSS JOIN
        `${var.project_id}.zoomcamp_dota_project.total_matches_view` AS tm
      GROUP BY
        h.localized_name,
        tm.total_matches
      ORDER BY
        pick_rate DESC,
        win_rate ASC
    SQL
  }
}

resource "google_bigquery_data_transfer_config" "low_skill_pick_and_win_rates" {
  display_name           = "low skill pick and win rates"
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  location               = var.region
  schedule               = "every day 03:10"

  depends_on = [
    google_bigquery_data_transfer_config.stg_player_hero_wins,
    google_bigquery_data_transfer_config.stg_low_skill_player,
  ]

  params = {
    query = <<-SQL
      CREATE OR REPLACE TABLE `${var.project_id}.zoomcamp_dota_project.low_skill_pick_and_win_rates` AS
      WITH low_skill_matches AS (
        SELECT DISTINCT
          s.match_id
        FROM
          `${var.project_id}.zoomcamp_dota_project.stg_player_hero_wins` AS s
        JOIN
          `${var.project_id}.zoomcamp_dota_project.stg_low_skill_player` AS lsp
          ON s.account_id = lsp.account_id
      ),
      total_low_skill_matches AS (
        SELECT
          COUNT(match_id) AS total_matches
        FROM
          low_skill_matches
      )
      SELECT
        h.localized_name,
        COUNT(s.match_id) / tlsm.total_matches AS pick_rate,
        SUM(s.is_win) / COUNT(s.match_id) AS win_rate
      FROM
        `${var.project_id}.zoomcamp_dota_project.stg_player_hero_wins` AS s
      JOIN
        `${var.project_id}.zoomcamp_dota_project.stg_low_skill_player` AS lsp
        ON s.account_id = lsp.account_id
      JOIN
        `${var.project_id}.zoomcamp_dota_project.hero_names` AS h
        ON s.hero_id = h.hero_id
      CROSS JOIN
        total_low_skill_matches AS tlsm
      GROUP BY
        h.localized_name,
        tlsm.total_matches
      ORDER BY
        pick_rate DESC,
        win_rate ASC
    SQL
  }
}

resource "google_bigquery_data_transfer_config" "high_skill_pick_and_win_rates" {
  display_name           = "high skill pick and win rates"
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  location               = var.region
  schedule               = "every day 03:10"

  depends_on = [
    google_bigquery_data_transfer_config.stg_player_hero_wins,
    google_bigquery_data_transfer_config.stg_high_skill_player,
  ]

  params = {
    query = <<-SQL
      CREATE OR REPLACE TABLE `${var.project_id}.zoomcamp_dota_project.high_skill_pick_and_win_rates` AS
      WITH high_skill_matches AS (
        SELECT DISTINCT
          s.match_id
        FROM
          `${var.project_id}.zoomcamp_dota_project.stg_player_hero_wins` AS s
        JOIN
          `${var.project_id}.zoomcamp_dota_project.stg_high_skill_player` AS hsp
          ON s.account_id = hsp.account_id
      ),
      total_high_skill_matches AS (
        SELECT
          COUNT(match_id) AS total_matches
        FROM
          high_skill_matches
      )
      SELECT
        h.localized_name,
        COUNT(s.match_id) / thsm.total_matches AS pick_rate,
        SUM(s.is_win) / COUNT(s.match_id) AS win_rate
      FROM
        `${var.project_id}.zoomcamp_dota_project.stg_player_hero_wins` AS s
      JOIN
        `${var.project_id}.zoomcamp_dota_project.stg_high_skill_player` AS hsp
        ON s.account_id = hsp.account_id
      JOIN
        `${var.project_id}.zoomcamp_dota_project.hero_names` AS h
        ON s.hero_id = h.hero_id
      CROSS JOIN
        total_high_skill_matches AS thsm
      GROUP BY
        h.localized_name,
        thsm.total_matches
      ORDER BY
        pick_rate DESC,
        win_rate ASC
    SQL
  }
}

resource "google_bigquery_data_transfer_config" "pearson_coefficients" {
  display_name           = "Pearson correlation coefficients"
  data_source_id         = "scheduled_query"
  destination_dataset_id = google_bigquery_dataset.zoomcamp_dota_project.dataset_id
  location               = var.region
  schedule               = "every day 03:15"

  depends_on = [
    google_bigquery_data_transfer_config.hero_pick_and_win_rates,
    google_bigquery_data_transfer_config.low_skill_pick_and_win_rates,
    google_bigquery_data_transfer_config.high_skill_pick_and_win_rates,
  ]

  params = {
    query = <<-SQL
      CREATE OR REPLACE TABLE `${var.project_id}.zoomcamp_dota_project.pearson_coefficients` AS
      SELECT "All players" as player_skill_level, CORR(pick_rate, win_rate) as correlation_coefficient FROM `${var.project_id}.zoomcamp_dota_project.hero_pick_and_win_rates`
      UNION ALL
      SELECT "Low-skill players" as player_skill_level, CORR(pick_rate, win_rate) as correlation_coefficient FROM `${var.project_id}.zoomcamp_dota_project.low_skill_pick_and_win_rates`
      UNION ALL
      SELECT "High-skill players" as player_skill_level, CORR(pick_rate, win_rate) as correlation_coefficient FROM `${var.project_id}.zoomcamp_dota_project.high_skill_pick_and_win_rates`
    SQL
  }
}
