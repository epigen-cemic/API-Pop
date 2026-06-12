# Prepare or validate the local API-POP app data store
# -----------------------------------------------------------------------------
# Run from the project root. This helper is intended for the local SQLite app
# data store only. External databases should be created/migrated by the database
# owner, then checked with connect_database_example.R.

library(config)
library(DBI)
library(RSQLite)
library(pool)
library(here)
library(stringi)

source(here::here("R", "shared", "config_helpers.R"))
source(here::here("R", "utils.R"))
source(here::here("R", "shared", "database_helpers.R"))

create_reports_table_if_missing <- function(con, table_name = "reports") {
  if (DBI::dbExistsTable(con, table_name)) {
    return(invisible(FALSE))
  }

  sql <- sprintf(
    paste(
      "CREATE TABLE %s (",
      "id_code TEXT,",
      "consultation_date TEXT,",
      "sex TEXT,",
      "birth_date TEXT,",
      "country TEXT,",
      "level1 TEXT,",
      "level2 TEXT,",
      "locality TEXT,",
      "level3 TEXT,",
      "symptom_onset_date TEXT,",
      "symptom_description TEXT,",
      "suspected_diagnosis TEXT,",
      "confirmation_time TEXT,",
      "email TEXT,",
      "institution TEXT,",
      "country_norm TEXT,",
      "level1_norm TEXT,",
      "level2_norm TEXT,",
      "level3_norm TEXT",
      ")"
    ),
    DBI::dbQuoteIdentifier(con, table_name)
  )

  DBI::dbExecute(con, sql)
  invisible(TRUE)
}

app_config <- config::get(file = here::here("config.yaml"))
db_settings <- get_database_settings(app_config)
if (!identical(db_settings$type, "sqlite")) {
  stop(
    "prepare_api_pop_database.R only prepares the local SQLite app data store. ",
    "Use connect_database_example.R to check external databases.",
    call. = FALSE
  )
}

table_name <- get_database_table(app_config)
con <- connect_app_database(app_config, create_pool = FALSE)
on.exit(disconnect_app_database(con), add = TRUE)

created <- create_reports_table_if_missing(con, table_name)
ensure_reports_schema(con, table_name)

cat("API-POP local app data preparation\n")
cat("==================================\n\n")
cat("Table:", table_name, "\n")
cat("Created table:", created, "\n\n")

cat("Schema\n")
cat("------\n")
print(database_schema_report(con, table_name))
