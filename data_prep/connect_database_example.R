# API-POP active data source connection example
# -----------------------------------------------------------------------------
# Run from the project root. This script does not modify data; it only checks
# whether the configured data source can be opened and whether the reports table
# is available. File uploads can remain enabled even when the app is configured
# to use an external database.

library(config)
library(DBI)
library(RSQLite)
library(pool)
library(here)

source(here::here("R", "shared", "config_helpers.R"))
source(here::here("R", "shared", "database_helpers.R"))

app_config <- config::get(file = here::here("config.yaml"))

cat("API-POP data source connection check\n")
cat("====================================\n\n")

cat("Data source settings\n")
cat("--------------------\n")
print(get_data_source_settings(app_config))
cat("\nConnection check\n")
cat("----------------\n")
print(test_database_connection(app_config))

con <- connect_app_database(app_config, create_pool = FALSE)
on.exit(disconnect_app_database(con), add = TRUE)

cat("\nSchema\n")
cat("------\n")
print(database_schema_report(con, get_database_table(app_config)))
