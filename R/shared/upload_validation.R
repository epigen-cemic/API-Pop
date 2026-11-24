# =============================================================================
# Shared upload validation helpers
# =============================================================================

#' List supported upload file extensions
#'
#' Return the extensions the current upload interface advertises as supported.
#'
#' @return A character vector of extensions.
#' @keywords internal
supported_upload_extensions <- function() {
  c("csv", "xlsx", "xml", "dba", "sqlite", "db")
}

#' Classify an uploaded data frame
#'
#' Reject unreadable, nontabular, or empty uploads, and indicate whether uploaded columns require
#' mapping before append.
#'
#' @param df Data frame containing input or output records.
#' @param target_cols Names of fields expected by the destination table.
#' @return A list with allowed, status, and message entries.
#' @keywords internal
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

#' Check minimal mapped upload content
#'
#' Check that active tabular data is nonempty and that any present consultation_date or country
#' column is not entirely empty.
#'
#' @details This checks whether present essential columns are entirely empty; it is not
#'   comprehensive row-by-row validation.
#'
#' @param df Data frame containing input or output records.
#' @return NULL when no problem is identified, otherwise an error message.
#' @keywords internal
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

#' Build the upload-review table
#'
#' Summarize staged input filenames, row counts, date ranges, sizes, and validation status.
#'
#' @param staged_files Named list of staged upload descriptors.
#' @return A data frame for the upload-review UI.
#' @keywords internal
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

#' Combine active, allowed uploads
#'
#' Concatenate the datasets of staged files selected by the user and permitted by initial
#' validation.
#'
#' @param staged_files Named list of staged upload descriptors.
#' @param active_ids Identifiers of staged files selected for inclusion.
#' @return A combined data frame with upload_file_id, or NULL.
#' @keywords internal
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
