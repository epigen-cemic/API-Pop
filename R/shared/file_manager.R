# =============================================================================
# Shared file metadata helpers
# =============================================================================

format_file_size <- function(bytes) {
  if (is.null(bytes) || is.na(bytes)) {
    return("")
  }

  bytes <- suppressWarnings(as.numeric(bytes))
  if (is.na(bytes)) {
    return("")
  }

  if (bytes < 1024) {
    return(paste0(bytes, " B"))
  }

  if (bytes < 1024^2) {
    return(paste0(round(bytes / 1024, 1), " KB"))
  }

  paste0(round(bytes / 1024^2, 1), " MB")
}

get_case_date_range <- function(dat) {
  if (is.null(dat) || nrow(dat) == 0) {
    return("")
  }

  date_col <- intersect(
    c("consultation_date", "symptom_onset_date", "date", "Date", "fecha", "Fecha"),
    names(dat)
  )

  if (length(date_col) == 0) {
    return("")
  }

  date_col <- date_col[[1]]
  dates <- suppressWarnings(as.Date(dat[[date_col]]))
  dates <- dates[!is.na(dates)]

  if (length(dates) == 0) {
    return("")
  }

  paste0(format(min(dates), "%Y-%m-%d"), " to ", format(max(dates), "%Y-%m-%d"))
}
