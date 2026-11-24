# =============================================================================
# Shared database helpers
# =============================================================================

#' Read data-source options
#'
#' Resolve the configured operating mode, upload availability, database type, and destination
#' table.
#'
#' @param app_config Parsed application configuration, including local database settings.
#' @return A list of normalized data-source settings.
#' @keywords internal
get_data_source_settings <- function(app_config) {
  source_cfg <- app_config$data_source %||% list()
  db_cfg <- app_config$database %||% list()
  db_type <- tolower(db_cfg$type %||% "sqlite")

  mode <- tolower(source_cfg$mode %||% if (identical(db_type, "sqlite")) "local" else "external_database")
  if (mode %in% c("external", "external_db", "database", "odbc")) {
    mode <- "external_database"
  }

  upload_enabled <- source_cfg$upload_enabled
  if (is.null(upload_enabled)) {
    upload_enabled <- TRUE
  }

  list(
    mode = mode,
    upload_enabled = isTRUE(upload_enabled),
    database_type = db_type,
    table = db_cfg$table %||% "reports"
  )
}

#' Read database connection settings
#'
#' Combine database configuration with defaults and optional environment-based ODBC credentials.
#'
#' @param app_config Parsed application configuration, including local database settings.
#' @return A list of database driver, path, table, DSN, and credential settings.
#' @keywords internal
get_database_settings <- function(app_config) {
  db_cfg <- app_config$database %||% list()

  list(
    type = tolower(db_cfg$type %||% "sqlite"),
    path = db_cfg$path %||% if (!is.null(app_config$db_name)) file.path("data", app_config$db_name) else NULL,
    table = db_cfg$table %||% "reports",
    dsn = db_cfg$dsn %||% NULL,
    database = db_cfg$database %||% NULL,
    uid = db_cfg$uid %||% Sys.getenv("API_POP_DB_UID", unset = ""),
    pwd = db_cfg$pwd %||% Sys.getenv("API_POP_DB_PWD", unset = "")
  )
}

#' Resolve the reports table name
#'
#' Return the configured database table or its fallback name.
#'
#' @param app_config Parsed application configuration, including local database settings.
#' @param default Fallback table or field name if not configured.
#' @return A character scalar naming the table.
#' @keywords internal
get_database_table <- function(app_config, default = "reports") {
  settings <- get_database_settings(app_config)
  settings$table %||% default
}

#' Resolve a local database filename
#'
#' Keep absolute paths unchanged and resolve relative paths from the project root.
#'
#' @param path Filesystem path from the application configuration.
#' @return An absolute or project-resolved filesystem path.
#' @keywords internal
resolve_database_path <- function(path) {
  if (is.null(path) || !nzchar(path)) {
    stop("No database path was configured.", call. = FALSE)
  }

  is_absolute <- grepl("^([A-Za-z]:)?[\\\\/]", path)
  if (is_absolute) {
    return(path)
  }

  here::here(path)
}

#' Connect to the configured database
#'
#' Open a pooled or direct SQLite/ODBC connection. For SQLite, create the parent directory and
#' allow the driver to create a database file if missing.
#'
#' @details Connection creation has side effects for SQLite: a missing file may be created. This is
#'   not a read-only capability check.
#'
#' @param app_config Parsed application configuration, including local database settings.
#' @param create_pool Whether to return a pool instead of a direct DBI connection.
#' @return A connection pool or DBI connection.
#' @keywords internal
connect_app_database <- function(app_config, create_pool = TRUE) {
  settings <- get_database_settings(app_config)

  if (identical(settings$type, "sqlite")) {
    db_path <- resolve_database_path(settings$path)
    # SQLite may create a new database file on connection; this is a writable path.
    dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)

    if (isTRUE(create_pool)) {
      return(pool::dbPool(drv = RSQLite::SQLite(), dbname = db_path))
    }

    return(DBI::dbConnect(RSQLite::SQLite(), dbname = db_path))
  }

  if (identical(settings$type, "odbc")) {
    if (!requireNamespace("odbc", quietly = TRUE)) {
      stop("The odbc package is required for ODBC database connections.", call. = FALSE)
    }
    if (is.null(settings$dsn) || !nzchar(settings$dsn)) {
      stop("ODBC database type requires database.dsn in config.yaml.", call. = FALSE)
    }

    args <- list(drv = odbc::odbc(), dsn = settings$dsn)
    if (!is.null(settings$database) && nzchar(settings$database)) args$database <- settings$database
    if (!is.null(settings$uid) && nzchar(settings$uid)) args$uid <- settings$uid
    if (!is.null(settings$pwd) && nzchar(settings$pwd)) args$pwd <- settings$pwd

    if (isTRUE(create_pool)) {
      return(do.call(pool::dbPool, args))
    }

    return(do.call(DBI::dbConnect, args))
  }

  stop("Unsupported database type: ", settings$type, call. = FALSE)
}

#' Close a configured database connection
#'
#' Close a pool or disconnect a valid direct DBI connection.
#'
#' @param con A DBI database connection or compatible pool.
#' @return Invisible TRUE.
#' @keywords internal
disconnect_app_database <- function(con) {
  if (inherits(con, "Pool")) {
    pool::poolClose(con)
    return(invisible(TRUE))
  }

  if (DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
  }

  invisible(TRUE)
}

#' Inspect access to the configured reports table
#'
#' Connect to the selected database, check whether the reports table is visible, and count its rows
#' if present. This check does not establish write permission.
#'
#' @details The connection helper may create a missing SQLite file as a side effect; table
#'   visibility does not establish insert privileges.
#'
#' @param app_config Parsed application configuration, including local database settings.
#' @param table_name Name of the reports table to inspect or modify.
#' @return A one-row data frame describing the connection and table visibility.
#' @keywords internal
test_database_connection <- function(app_config, table_name = NULL) {
  con <- connect_app_database(app_config, create_pool = FALSE)
  on.exit(disconnect_app_database(con), add = TRUE)

  table_name <- table_name %||% get_database_table(app_config)
  tables <- DBI::dbListTables(con)
  table_exists <- table_name %in% tables

  data.frame(
    database_type = get_database_settings(app_config)$type,
    table = table_name,
    table_exists = table_exists,
    rows = if (table_exists) DBI::dbGetQuery(con, paste("SELECT COUNT(*) AS n FROM", DBI::dbQuoteIdentifier(con, table_name)))$n[[1]] else NA_integer_,
    stringsAsFactors = FALSE
  )
}

#' Inspect destination-table fields
#'
#' Read SQLite table metadata where supported and fall back to DBI field names for other drivers.
#'
#' @param con A DBI database connection or compatible pool.
#' @param table_name Name of the reports table to inspect or modify.
#' @return A data frame containing column names and declared types, when available.
#' @keywords internal
database_schema_report <- function(con, table_name = "reports") {
  if (!DBI::dbExistsTable(con, table_name)) {
    return(data.frame(Column = character(0), Type = character(0), stringsAsFactors = FALSE))
  }

  info <- tryCatch({
    DBI::dbGetQuery(con, paste0("PRAGMA table_info(", DBI::dbQuoteIdentifier(con, table_name), ")"))
  }, error = function(e) NULL)

  if (!is.null(info) && all(c("name", "type") %in% names(info))) {
    return(data.frame(Column = info$name, Type = info$type, stringsAsFactors = FALSE))
  }

  data.frame(Column = DBI::dbListFields(con, table_name), Type = NA_character_, stringsAsFactors = FALSE)
}

#' Normalize geographic fields in records
#'
#' Add normalized companion columns for each geographic field present in a data frame.
#'
#' @param df Data frame containing input or output records.
#' @return The input data frame with available geographic normalization columns.
#' @keywords internal
add_geographic_norm_columns <- function(df) {
  for (col in c("country", "level1", "level2", "level3")) {
    if (col %in% names(df)) {
      df[[paste0(col, "_norm")]] <- normalize(df[[col]])
    }
  }
  df
}

#' Add missing normalized report columns
#'
#' Alter an existing reports table to add missing geographic normalization columns, then backfill
#' their values. This function changes the database.
#'
#' @details This operation executes ALTER TABLE statements and a follow-up backfill against
#'   existing rows. Run only against a writable destination that the application is authorized to
#'   modify.
#'
#' @param con A DBI database connection or compatible pool.
#' @param table_name Name of the reports table to inspect or modify.
#' @return Invisible TRUE on completion.
#' @keywords internal
ensure_reports_schema <- function(con, table_name = "reports") {
  if (!DBI::dbExistsTable(con, table_name)) {
    stop("Required database table not found: ", table_name, call. = FALSE)
  }

  existing_cols <- DBI::dbListFields(con, table_name)
  required_norm_cols <- paste0(c("country", "level1", "level2", "level3"), "_norm")

  for (col in setdiff(required_norm_cols, existing_cols)) {
    sql <- sprintf(
      "ALTER TABLE %s ADD COLUMN %s TEXT",
      DBI::dbQuoteIdentifier(con, table_name),
      DBI::dbQuoteIdentifier(con, col)
    )
    DBI::dbExecute(con, sql)
  }

  backfill_report_norm_columns(con, table_name)
  invisible(TRUE)
}

#' Populate missing geographic normalization values
#'
#' For records with an id_code, update empty normalized geographic fields from their original
#' values. Existing nonempty normalized fields are left unchanged.
#'
#' @details Existing nonblank normalization values are not overwritten; records are located by
#'   id_code.
#'
#' @param con A DBI database connection or compatible pool.
#' @param table_name Name of the reports table to inspect or modify.
#' @return Invisible TRUE on completion or FALSE when id_code is absent.
#' @keywords internal
backfill_report_norm_columns <- function(con, table_name = "reports") {
  cols <- DBI::dbListFields(con, table_name)
  if (!"id_code" %in% cols) {
    return(invisible(FALSE))
  }

  for (col in c("country", "level1", "level2", "level3")) {
    norm_col <- paste0(col, "_norm")
    if (!all(c(col, norm_col) %in% cols)) {
      next
    }

    query <- sprintf(
      "SELECT %s, %s FROM %s WHERE %s IS NOT NULL AND (%s IS NULL OR %s = '')",
      DBI::dbQuoteIdentifier(con, "id_code"),
      DBI::dbQuoteIdentifier(con, col),
      DBI::dbQuoteIdentifier(con, table_name),
      DBI::dbQuoteIdentifier(con, col),
      DBI::dbQuoteIdentifier(con, norm_col),
      DBI::dbQuoteIdentifier(con, norm_col)
    )

    values <- DBI::dbGetQuery(con, query)
    if (nrow(values) == 0) {
      next
    }

    values[[norm_col]] <- normalize(values[[col]])
    update_sql <- sprintf(
      "UPDATE %s SET %s = ? WHERE %s = ?",
      DBI::dbQuoteIdentifier(con, table_name),
      DBI::dbQuoteIdentifier(con, norm_col),
      DBI::dbQuoteIdentifier(con, "id_code")
    )

    # Update by record identifier to avoid overwriting unrelated rows.
    for (i in seq_len(nrow(values))) {
      DBI::dbExecute(con, update_sql, params = list(values[[norm_col]][[i]], values$id_code[[i]]))
    }
  }

  invisible(TRUE)
}
