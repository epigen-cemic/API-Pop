# =============================================================================
# Shared upload validation helpers
# =============================================================================

supported_upload_extensions <- function() {
  c("csv", "xlsx", "xml", "dba", "sqlite", "db")
}

validate_staged_upload <- function(df, target_cols = character(0)) {
  if (is.null(df)) {
    return(list(allowed = FALSE, status = "Disallowed", message = "The file could not be read."))
  }

  if (!is.data.frame(df)) {
    return(list(allowed = FALSE, status = "Disallowed", message = "The file did not produce a tabular dataset."))
  }

  if (nrow(df) == 0) {
    return(list(allowed = FALSE, status = "Disallowed", message = "The file is empty."))
  }

  matching_cols <- intersect(names(df), target_cols)
  if (length(matching_cols) == 0) {
    return(list(
      allowed = TRUE,
      status = "Allowed with mapping",
      message = "No database columns matched exactly; review column mapping before appending."
    ))
  }

  unmatched_cols <- setdiff(names(df), target_cols)
  if (length(unmatched_cols) > 0) {
    return(list(
      allowed = TRUE,
      status = "Allowed with mapping",
      message = paste("Exact matches:", length(matching_cols), "| Columns to review:", length(unmatched_cols))
    ))
  }

  list(allowed = TRUE, status = "Allowed", message = "All columns match the database schema.")
}

validate_database_ready_upload <- function(df) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) {
    return("No active rows are available to append.")
  }

  essential <- intersect(c("consultation_date", "country"), names(df))
  for (col in essential) {
    values <- df[[col]]
    empty <- is.na(values) | trimws(as.character(values)) == ""
    if (all(empty)) {
      return(paste("The", col, "column is empty after mapping. Please check the upload or mapping."))
    }
  }

  NULL
}

staged_upload_summary <- function(staged_files) {
  if (length(staged_files) == 0) {
    return(data.frame(
      File = character(0),
      Rows = integer(0),
      DateRange = character(0),
      Size = character(0),
      Status = character(0),
      Message = character(0),
      stringsAsFactors = FALSE
    ))
  }

  do.call(
    rbind,
    lapply(staged_files, function(item) {
      data.frame(
        File = item$name %||% "",
        Rows = item$rows %||% NA_integer_,
        DateRange = item$date_range %||% "",
        Size = format_file_size(item$size %||% NA_real_),
        Status = item$status %||% "",
        Message = item$message %||% "",
        stringsAsFactors = FALSE
      )
    })
  )
}

active_staged_uploads <- function(staged_files, active_ids) {
  if (length(staged_files) == 0 || length(active_ids) == 0) {
    return(NULL)
  }

  active <- staged_files[names(staged_files) %in% active_ids]
  active <- active[vapply(active, function(item) isTRUE(item$allowed), logical(1))]

  if (length(active) == 0) {
    return(NULL)
  }

  dplyr::bind_rows(lapply(active, function(item) item$data), .id = "upload_file_id")
}
