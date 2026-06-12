# =============================================================================
# Shared export helpers
# =============================================================================

timestamped_filename <- function(prefix, ext = "csv", time = Sys.time()) {
  paste0(prefix, "_", format(time, "%Y%m%d_%H%M%S"), ".", ext)
}

sanitize_filename_part <- function(x) {
  x <- as.character(x %||% "")
  x <- trimws(x)
  x <- gsub("[^A-Za-z0-9._-]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  if (!nzchar(x)) "unknown" else x
}

write_csv_utf8 <- function(df, file) {
  utils::write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8", na = "")
}
