#' Build the main analysis interface
#'
#' Compose the upload, filtering, results, and export Shiny modules within the analysis page.
#'
#' @param id Character Shiny module identifier used for namespacing.
#' @return A Shiny UI tag tree.
#' @export
analysisUI <- function(id) {
  ns <- NS(id)

  tagList(
    # Load CSS and Title for this module
    tags$head(
      tags$title("API Population"),
      tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
    ),

    # 1. Top Navigation Bar
    div(class = "nav-bar",
        div(class = "nav-content",
            div(class = "header-logo-left")
        )
    ),

    # 2. Hero Title Section
    div(class = "hero-section",
        div(class = "hero-content",
            h1(class = "app-title", "API Population")
        )
    ),

    # 3. Main Application Content
    div(class = "content-wrapper api-pop-page",
        div(class = "api-pop-shell",
            sidebarLayout(
              sidebarPanel(
                class = "api-sidebar-panel",
                div(class = "sidebar-section-title", "Data"),

                # Call Upload Module UI
                uploadUI(ns("upload_mod")),

                div(class = "sidebar-section-title", "Filter by"),

                # Call Filters Module UI
                filtersUI(ns("filters_mod")),

                # Output bindings for Results Module Downloads
                div(class = "btn-container api-downloads",
                    downloadButton(ns("results_mod-download_csv"), "Cases List"),
                    downloadButton(ns("results_mod-download_summary_csv"), "Weekly Summary")
                )
              ),
              mainPanel(
                class = "api-results-panel",
                div(
                  class = "api-results-card",
                  div(class = "output-card-title", "Query results"),
                  DT::DTOutput(ns("results_mod-results"))
                )
              )
            )
        )
    )
  )
}

#' Coordinate the analysis workflow
#'
#' Connect upload, filter, database query, and results modules. A filter change triggers a read
#' from the configured reports table.
#'
#' @param id Character Shiny module identifier used for namespacing.
#' @param con A DBI database connection or compatible pool.
#' @param gpkg_path Path to the country GeoPackage containing configured geographic layers.
#' @return The Shiny module server result (used for side effects).
#' @export
analysisServer <- function(id, con, gpkg_path) {
  moduleServer(id, function(input, output, session) {

    # 1. Initialize Upload Sub-Module
    uploadServer(
      id = "upload_mod",
      con = con,
      target_table = table_name,
      target_cols = reports_cols,
      data_source_settings = data_source_settings
    )

    # 2. Initialize Filters Sub-Module
    active_filters <- filtersServer(
      id = "filters_mod",
      columns = columns,
      display_names = display_names,
      population_layers = population_layers
    )

    # --- 3. Main Data Query Logic ---
    data_reactive <- reactive({
      req(active_filters())
      filters <- active_filters()

      # A. Determine geographic columns (This handles the UI layout)
      if (isTruthy(filters$country) && !is.null(ALL_CONFIGS[[filters$country]])) {
        base_geo_cols <- ALL_CONFIGS[[filters$country]]$levels
      } else {
        base_geo_cols <- c("country")
      }

      # B. Build the SELECT statement
      select_cols <- c("suspected_diagnosis", "symptom_description", "symptom_onset_date",
                       base_geo_cols,
                       "consultation_date", "sex",
                       "CAST((julianday(consultation_date) - julianday(birth_date)) / 365.25 AS INT) AS Age")

      sql <- paste("SELECT", paste(select_cols, collapse = ", "),
                   "FROM", DBI::dbQuoteIdentifier(con, table_name))


      # Combine standard filters with these geography selections
      # This ensures the SQL builder sees them as equality constraints
      all_filters <- filters$eq_filters

      # D. Build the final SQL with the merged list
      sql <- add_filters_to_sql(
        sql = sql,
        con = con,
        eq_filters = all_filters,
        range_filters = filters$range_filters,
        age_range = filters$age_range
      )

      result <- DBI::dbGetQuery(con, sql)

      # Preserve the query result for downstream table rendering and exports.
      return(result)
    })

    # 4. Initialize Results Sub-Module
    resultsServer(
      id = "results_mod",
      data_reactive = data_reactive,
      cols_for_table = cols_for_table,
      display_names = display_names,
      filter_metadata = reactive({
        list(
          country = active_filters()$country,
          level1 = active_filters()$level1,
          level2 = active_filters()$level2
        )
      }),
      ALL_CONFIGS = ALL_CONFIGS,
      gpkg_path = gpkg_path
    )

  })
}
