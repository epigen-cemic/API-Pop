# =============================================================================
# Shared DT table helpers
# =============================================================================

#' Create a standard RAP data table
#'
#' Build a DT table with the application-specific pagination and display options.
#'
#' @param df Data frame containing input or output records.
#' @param page_length Number of rows to show on each DT page.
#' @return A DT HTML widget.
#' @keywords internal
app_datatable <- function(df, page_length = 10) {
  DT::datatable(
    df,
    extensions = "Buttons",
    options = list(
      pageLength = page_length,
      scrollX = TRUE,
      searchHighlight = TRUE,
      dom = "Blfrtip",
      buttons = list(
        list(extend = "colvis", text = "Show / hide columns")
      ),
      columnDefs = list(
        list(className = "dt-left", targets = "_all")
      )
    ),
    rownames = FALSE
  )
}
