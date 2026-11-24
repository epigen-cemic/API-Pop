# =============================================================================
# Shared export helpers
# =============================================================================

#' Generate a timestamped export filename
#'
#' Combine a filename prefix, timestamp, and extension to reduce collisions between downloads.
#'
#' @param prefix Filename prefix.
#' @param ext Filename extension without the leading dot.
#' @param time Timestamp used to construct the filename.
#' @return A character filename.
#' @keywords internal
timestamped_filename <- function(prefix, ext = "csv", time = Sys.time()) {
  paste0(prefix, "_", format(time, "%Y%m%d_%H%M%S"), ".", ext)
}

#' Clean a filename component
#'
#' Replace unsupported characters with underscores and provide a fallback for an empty value.
#'
#' @param x Input value or object to process.
#' @return A filename-safe character value.
#' @keywords internal
sanitize_filename_part <- function(x) {
  x <- as.character(x %||% "")
  x <- trimws(x)
  x <- gsub("[^A-Za-z0-9._-]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  if (!nzchar(x)) "unknown" else x
}

#' Write a UTF-8 CSV export
#'
#' Write a data frame as CSV with a header, no row names, and empty fields for missing values.
#'
#' @param df Data frame containing input or output records.
#' @param file File path for writing the export.
#' @return Invisible result of utils::write.csv().
#' @keywords internal
write_csv_utf8 <- function(df, file) {
  utils::write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8", na = "")
}
