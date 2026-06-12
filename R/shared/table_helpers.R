# =============================================================================
# Shared DT table helpers
# =============================================================================

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
