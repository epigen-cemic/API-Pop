#' Build the case-filter interface
#'
#' Display dynamic controls for available database columns, cascading geographic selectors, and
#' actions for applying or resetting filters.
#'
#' @param id Character Shiny module identifier used for namespacing.
#' @return A Shiny UI tag tree.
#' @export
filtersUI <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("filter_ui")),
    div(class = "btn-container",
        actionButton(ns("run"), "Run Query", class = "btn-block"),
        actionButton(ns("reset"), "Reset Selections")
    ),
    tags$small(
      class = "filter-help-text",
      "Population source is selected automatically from the configured spatial layer."
    )
  )
}

#' Manage reactive case filters
#'
#' Create filter inputs from the available columns, update dependent geographic selectors, and
#' expose the selected filter values when the user applies them.
#'
#' @param id Character Shiny module identifier used for namespacing.
#' @param columns Named set of available database fields and filter control types.
#' @param display_names Mapping of internal field names to user-facing labels.
#' @param population_layers Legacy population-layer argument; accepted but not used by the current
#'   filter server.
#' @return A reactive expression yielding the selected filter values.
#' @export
filtersServer <- function(id, columns, display_names, population_layers) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # --- 1. Render Dynamic Filters ---
    output$filter_ui <- renderUI({
      # Wait until the destination columns are available before building controls.
      if (is.null(columns) || length(columns) == 0) return(tags$p("Initializing filters..."))

      tryCatch({
        tagList(
          lapply(names(columns), function(col) {
            # --- A. Safe Data Extraction ---
            col_str <- as.character(col)
            col_type <- as.character(columns[[col_str]])

            # Use the internal column name when no display label is configured.
            display <- if(col_str %in% names(display_names)) as.character(display_names[[col_str]]) else col_str
            if(length(display) == 0 || is.na(display) || display == "") display <- col_str

            # --- B. The Filter Container ---
            # The filter wrapper is styled by the shared application stylesheet.
            div(class = "filter-box",
                # Top Level: The Toggle Checkbox
                div(
                  checkboxInput(ns(paste0("chk_", col_str)), display, value = FALSE)
                ),

                # Sub Level: The Actual Inputs (Visible only when checked)
                conditionalPanel(
                  condition = sprintf("input.chk_%s == true", col_str),
                  ns = ns,
                  tags$hr(),

                  # --- C. Logic by Type ---
                  # Keep each control within the expected filter-container structure.
                  if(col_type == "text") {
                    textInput(ns(paste0("val_", col_str)), NULL, placeholder = paste("Enter", display))
                  }

                  else if (col_type == "text_logic") {
                    tagList(
                      textInput(ns(paste0("val_", col_str)), display, placeholder = paste("Enter", display)),
                      div(class = "btn-container",
                          actionButton(ns(paste0("btn_and_", col_str)), "AND"),
                          actionButton(ns(paste0("btn_or_", col_str)), "OR")
                      )
                    )
                  }

                  else if(col_type == "date_or_range") {
                    tagList(
                      radioButtons(ns(paste0("mode_", col_str)), "Filter type",
                                   choices = c("Exact" = "exact", "Range" = "range"), inline = TRUE),
                      conditionalPanel(
                        condition = sprintf("input.mode_%s == 'exact'", col_str),
                        ns = ns,
                        dateInput(ns(paste0("val_", col_str)), paste("Select", display))
                      ),
                      conditionalPanel(
                        condition = sprintf("input.mode_%s == 'range'", col_str),
                        ns = ns,
                        dateRangeInput(ns(paste0("valrange_", col_str)), paste("Select", display, "range"))
                      )
                    )
                  }

                  else if(col_type == "age") {
                    sliderInput(ns("age_range"), "Select Age range", min=0, max=120, value=c(0,120))
                  }

                  else if(col_type == "geography") {
                    # Standardized geography dropdowns. Labels are read from config.json.
                    tagList(
                      selectInput(ns("country"), "Country", choices = c("Select country" = "", valid_country_names(ALL_CONFIGS))),
                      selectInput(ns("level1"), "Level 1", choices = ""),
                      selectInput(ns("level2"), "Level 2", choices = ""),
                      selectInput(ns("level3"), "Level 3", choices = "")
                    )
                  }
                )
            )
          })
        )
      }, error = function(e) {
        message("UI Rendering Error: ", e$message)
        tags$p(style="color:red; font-weight:bold;", paste("UI Error:", e$message))
      })
    })

    # --- 2. Standardized Location Cascading Logic ---

    # Keep geographic selection state consistent across dependent levels.

    # A country change resets and repopulates its first geographic level.
    observeEvent(input$country, {
      req(input$country)

      # Clear dependent selections before loading a new country hierarchy.
      updateSelectInput(session, "level1", choices = "")
      updateSelectInput(session, "level2", choices = "")
      updateSelectInput(session, "level3", choices = "")

      if (input$country == "" || input$country == "(Select Country)") return()

      # Get country-specific file path from the Global Config
      country_cfg <- ALL_CONFIGS[[input$country]]
      specific_gpkg <- here::here("data", country_cfg$file_name)

      level_keys <- get_mapping_keys(country_cfg)
      if (length(level_keys) < 1) return()
      level1_key <- level_keys[[1]]
      level2_key <- if (length(level_keys) >= 2) level_keys[[2]] else NULL
      level3_key <- if (length(level_keys) >= 3) level_keys[[3]] else NULL

      updateSelectInput(session, "level1", label = get_level_label(country_cfg, level1_key))
      updateSelectInput(session, "level2", label = if (!is.null(level2_key)) get_level_label(country_cfg, level2_key) else "Level 2")
      updateSelectInput(session, "level3", label = if (!is.null(level3_key)) get_level_label(country_cfg, level3_key) else "Level 3")

      # Load configured first-level geographic IDs and labels.
      opts <- fetch_options(
        gpkg_path = specific_gpkg,
        country = input$country,
        level_key = level1_key
      )

      session$userData$level1_key <- level1_key
      session$userData$level2_key <- level2_key
      session$userData$level3_key <- level3_key
      session$userData$level1_choices <- opts

      updateSelectInput(session, "level1", choices = c("", sort(opts)))
    })

    # Changes to level 1 invalidate level 2 and level 3 selections.
    observeEvent(input$level1, {
      req(input$level1, input$country)

      # Clear child selections before replacing the available options.
      updateSelectInput(session, "level2", choices = "")
      updateSelectInput(session, "level3", choices = "")

      if (input$level1 == "") return()

      country_cfg <- ALL_CONFIGS[[input$country]]
      specific_gpkg <- here::here("data", country_cfg$file_name)

      level1_key <- session$userData$level1_key %||% "level1"
      level2_key <- session$userData$level2_key %||% "level2"

      # Restrict second-level options to the selected first-level area.
      opts <- fetch_options(
        gpkg_path = specific_gpkg,
        country = input$country,
        level_key = level2_key,
        parent_key = level1_key,
        parent_val = input$level1
      )
      session$userData$level2_choices <- opts

      updateSelectInput(session, "level2", choices = c("", sort(opts)))
    })

    # Changes to level 2 invalidate the finest geographic selection.
    observeEvent(input$level2, {
      req(input$level2, input$level1, input$country)

      # Clear the finest-level selection before loading new options.
      updateSelectInput(session, "level3", choices = "")

      if (input$level2 == "") return()

      country_cfg <- ALL_CONFIGS[[input$country]]
      specific_gpkg <- here::here("data", country_cfg$file_name)

      level2_key <- session$userData$level2_key %||% "level2"
      level3_key <- session$userData$level3_key %||% "level3"

      # Restrict finest-level options to the selected second-level area.
      opts <- fetch_options(
        gpkg_path = specific_gpkg,
        country = input$country,
        level_key = level3_key,
        parent_key = level2_key,
        parent_val = input$level2
      )
      session$userData$level3_choices <- opts

      updateSelectInput(session, "level3", choices = c("", sort(opts)))
    })

    # Render text-query options only for columns configured with logic filters.
    observe({
      lapply(names(columns)[columns == "text_logic"], function(col) {
        observeEvent(input[[paste0("btn_and_", col)]], {
          current <- input[[paste0("val_", col)]]
          updateTextInput(session, paste0("val_", col),
                          value = paste0(trimws(current), ifelse(is.null(current) || current == "", "", " "), "and "))
        })
        observeEvent(input[[paste0("btn_or_", col)]], {
          current <- input[[paste0("val_", col)]]
          updateTextInput(session, paste0("val_", col),
                          value = paste0(trimws(current), ifelse(is.null(current) || current == "", "", " "), "or "))
        })
        output[[paste0("preview_", col)]] <- renderUI({
          txt <- input[[paste0("val_", col)]]
          if (is.null(txt) || txt == "") return(NULL)
          txt <- gsub("\\band\\b", "<span style='color:red;font-weight:bold'>and</span>", txt, ignore.case = TRUE)
          txt <- gsub("\\bor\\b", "<span style='color:red;font-weight:bold'>or</span>", txt, ignore.case = TRUE)
          HTML(txt)
        })
      })
    })

    # Reset the filter state when the user requests a fresh query.
    observeEvent(input$reset, {
      for (col in names(columns)) {
        updateCheckboxInput(session, paste0("chk_", col), value = FALSE)
      }
      updateSelectInput(session, "country", selected = "")
      updateSelectInput(session, "level1", choices = "")
      updateSelectInput(session, "level2", choices = "")
      updateSelectInput(session, "level3", choices = "")
    })

    # Publish selected filters only when the query is applied.
    active_filters <- eventReactive(input$run, {
      eq_filters <- list(); range_filters <- list()

      # Normalize the values returned by filter inputs.
      #' Normalize an input selection
      #'
      #' Convert an empty or unset input to NULL and delegate nonempty values to the global text
      #' normalizer.
      #'
      #' @param x Input value or object to process.
      #' @return A normalized input value or NULL.
      #' @keywords internal
      clean_input <- function(x) {
        if (is.null(x) || length(x) == 0) return(NULL)

        val <- x[1]
        if (length(val) == 0 || is.na(val) || !nzchar(as.character(val))) return(NULL)

        # Use the common normalization rules applied to query values.
        return(normalize(val))
      }

      # 1. Standard Filters (Symptoms, Diagnosis, etc.)
      for (col in names(columns)) {
        if (!isTRUE(input[[paste0("chk_", col)]])) next
        col_type <- columns[[col]]

        if (col_type %in% c("text", "text_logic")) {
          val <- clean_input(input[[paste0("val_", col)]])
          if (!is.null(val)) eq_filters[[col]] <- val
        } else if (col_type == "date_or_range") {
          mode <- input[[paste0("mode_", col)]]
          if (mode == "exact") {
            val <- clean_input(input[[paste0("val_", col)]])
            if (!is.null(val)) eq_filters[[col]] <- as.Date(val)
          } else {
            rng <- input[[paste0("valrange_", col)]]
            if (!is.null(rng)) range_filters[[col]] <- as.Date(rng)
          }
        }
      }

      # 2. Geography Logic
      if (isTRUE(input$chk_location)) {

        #' Resolve a geographic selection label
        #'
        #' Look up a selected geographic identifier in a named vector of selectable choices.
        #'
        #' @param id_val Selected geographic identifier.
        #' @param choices Named character vector of geographic choices where names are labels and
        #'   values are identifiers.
        #' @return The display label or a fallback value when the identifier is not matched.
        #' @keywords internal
        get_name <- function(id_val, choices) {
          if (!isTruthy(id_val)) return(NULL)
          lbl <- names(choices)[which(choices == id_val)]
          if (length(lbl) == 0) return(id_val)
          return(lbl[1])
        }

        geo_values <- list(
          country = input$country,
          level1  = get_name(input$level1, session$userData$level1_choices),
          level2  = get_name(input$level2, session$userData$level2_choices),
          level3  = input$level3
        )

        for (col in names(geo_values)) {
          val <- clean_input(geo_values[[col]])
          if (!is.null(val)) eq_filters[[col]] <- val
        }
      }

      list(
        eq_filters = eq_filters,
        range_filters = range_filters,
        age_range = input$age_range,
        country = input$country,
        level1 = input$level1,
        level2 = input$level2
      )
    })

    return(active_filters)
  })
}
