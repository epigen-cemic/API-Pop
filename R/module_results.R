#' Render and export analysis results
#'
#' Display filtered case records and export both the record list and a weekly geographic case-count
#' summary; the latter uses population geometry when available.
#'
#' @details Population in the weekly export is derived from the configured spatial source when a
#'   suitable join can be made; missing or mismatched spatial data may yield missing population
#'   values.
#'
#' @param id Character Shiny module identifier used for namespacing.
#' @param data_reactive Reactive expression yielding filtered case records.
#' @param cols_for_table Baseline columns displayed in the results table.
#' @param display_names Mapping of internal field names to user-facing labels.
#' @param filter_metadata Reactive expression returning selected filtering and geography metadata.
#' @param ALL_CONFIGS Named country configurations used by the application.
#' @param gpkg_path Path to the country GeoPackage containing configured geographic layers.
#' @return The Shiny module server result (used for side effects).
#' @export
resultsServer <- function(id, data_reactive, cols_for_table, display_names, filter_metadata, ALL_CONFIGS, gpkg_path) {
  moduleServer(id, function(input, output, session) {

    display_table_data <- reactive({
      req(data_reactive())
      df <- data_reactive()
      meta <- filter_metadata()

      # Start with the columns the app wants to show.
      target_cols <- cols_for_table

      # Include dynamic levels from the current country config.
      country_cfg <- NULL
      if (isTruthy(meta$country) && !is.null(ALL_CONFIGS)) {
        country_cfg <- tryCatch(ALL_CONFIGS[[meta$country]], error = function(e) NULL)
        if (!is.null(country_cfg)) {
          target_cols <- unique(c(target_cols, get_country_levels(country_cfg)))
        }
      }

      valid_cols <- intersect(target_cols, names(df))
      df <- df[, valid_cols, drop = FALSE]

      current_names <- colnames(df)
      new_names <- vapply(current_names, function(col) {
        if (!is.null(country_cfg) && col %in% get_mapping_keys(country_cfg)) {
          return(get_level_label(country_cfg, col))
        }
        if (col %in% names(display_names)) {
          return(display_names[[col]])
        }
        tools::toTitleCase(gsub("_", " ", col))
      }, character(1))
      colnames(df) <- new_names

      df
    })

    # 1. Render Table using the same DT pattern as the Digital Dashboard.
    output$results <- DT::renderDT({
      app_datatable(display_table_data(), page_length = 15)
    })

    #' Create the empty weekly-export schema
    #'
    #' Provide the expected summary columns when a query has no rows or cannot be summarized.
    #'
    #' @param config Optional country configuration for the summary schema.
    #' @return An empty data frame with export columns.
    #' @keywords internal
    empty_summary_template <- function(config = NULL) {
      geo_cols <- if (!is.null(config)) {
        get_country_levels(config)
      } else {
        c("country", "level1", "level2", "level3")
      }

      template <- as.data.frame(
        setNames(
          replicate(length(unique(c(geo_cols, "week", "year", "n_cases", "population"))), character(0), simplify = FALSE),
          unique(c(geo_cols, "week", "year", "n_cases", "population"))
        ),
        stringsAsFactors = FALSE
      )

      template$week <- integer(0)
      template$year <- integer(0)
      template$n_cases <- integer(0)
      template$population <- numeric(0)
      template
    }

    #' Select geography settings for summary export
    #'
    #' Use the selected country from the filter metadata or the available record data to identify
    #' the configuration for aggregation.
    #'
    #' @param meta Selected filter metadata, including country where available.
    #' @param df Data frame containing input or output records.
    #' @return The selected geographic configuration or NULL.
    #' @keywords internal
    resolve_summary_config <- function(meta, df) {
      selected_country <- meta$country %||% ""
      if (nzchar(selected_country) && !is.null(ALL_CONFIGS[[selected_country]])) {
        return(ALL_CONFIGS[[selected_country]])
      }

      if (!is.null(df) && "country" %in% names(df) && nrow(df) > 0) {
        data_country <- unique(stats::na.omit(as.character(df$country)))
        data_country <- data_country[data_country %in% names(ALL_CONFIGS)]
        if (length(data_country) > 0) {
          return(ALL_CONFIGS[[data_country[[1]]]])
        }
      }

      valid_countries <- valid_country_names(ALL_CONFIGS)
      if (length(valid_countries) > 0) {
        return(ALL_CONFIGS[[valid_countries[[1]]]])
      }

      NULL
    }

    # 2. Download Cases
    output$download_csv <- downloadHandler(
      filename = function() { timestamped_filename("query_results") },
      contentType = "text/csv; charset=utf-8",
      content = function(file) {
        df <- tryCatch(data_reactive(), error = function(e) NULL)
        if (is.null(df)) {
          df <- data.frame()
        }
        write_csv_utf8(df, file)
      }
    )

    # 3. Download Summary (Standardized RAP Version)
    output$download_summary_csv <- downloadHandler(
      filename = function() { timestamped_filename("weekly_summary") },
      contentType = "text/csv; charset=utf-8",
      content = function(file) {
        df <- tryCatch(data_reactive(), error = function(e) NULL)
        meta <- tryCatch(filter_metadata(), error = function(e) list())
        config <- resolve_summary_config(meta, df)

        if (is.null(df) || nrow(df) == 0 || is.null(config)) {
          write_csv_utf8(empty_summary_template(config), file)
          return(invisible(NULL))
        }

        finest_key <- get_finest_level_key(config)
        finest_map <- get_finest_mapping_config(config)

        if (is.null(finest_key) || is.null(finest_map) || !"consultation_date" %in% names(df)) {
          write_csv_utf8(empty_summary_template(config), file)
          return(invisible(NULL))
        }

        # A. Prep Year/Week from consultation_date.
        df <- df %>%
          dplyr::mutate(
            year = lubridate::isoyear(consultation_date),
            week = lubridate::isoweek(consultation_date)
          )

        # B. Summarize counts and retain the configured hierarchy.
        db_col <- finest_map$db_column %||% finest_key
        geo_cols <- intersect(get_country_levels(config), names(df))

        summary_df <- df %>%
          dplyr::group_by(year, week, dplyr::across(dplyr::all_of(geo_cols))) %>%
          dplyr::summarise(n_cases = dplyr::n(), .groups = "drop")

        final_df <- summary_df
        final_df$population <- NA_real_

        # Population denominators are joined from geography, not summed from case rows.
        # C. Join population when the configured GeoPackage/layer is available.
        specific_gpkg <- here::here("data", config$file_name)
        spatial_id_key <- finest_map$spatial_id

        if (
          file.exists(specific_gpkg) &&
            !is.null(finest_map$layer_name) &&
            !is.null(spatial_id_key) &&
            db_col %in% names(summary_df)
        ) {
          pop_df <- tryCatch(
            sf::st_read(specific_gpkg, layer = finest_map$layer_name, quiet = TRUE) %>%
              sf::st_drop_geometry(),
            error = function(e) NULL
          )

          if (!is.null(pop_df) && spatial_id_key %in% names(pop_df)) {
            population_col <- intersect(c("Population", "population", "pop", "total_population"), names(pop_df))

            if (length(population_col) > 0) {
              population_col <- population_col[[1]]
              summary_df[[db_col]] <- as.character(summary_df[[db_col]])
              pop_df[[spatial_id_key]] <- as.character(pop_df[[spatial_id_key]])

              final_df <- summary_df %>%
                dplyr::left_join(
                  pop_df %>%
                    dplyr::select(
                      dplyr::all_of(spatial_id_key),
                      population = dplyr::all_of(population_col)
                    ),
                  by = setNames(spatial_id_key, db_col)
                )
            }
          }
        }

        # D. Assemble final structure. Always return CSV, even for empty/partial outputs.
        final_cols <- names(empty_summary_template(config))
        missing_cols <- setdiff(final_cols, names(final_df))
        for (col in missing_cols) {
          final_df[[col]] <- NA
        }
        final_df <- final_df[, final_cols, drop = FALSE]

        write_csv_utf8(final_df, file)
      }
    )
  })
}
