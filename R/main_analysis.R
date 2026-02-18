#' @title Main Analysis Module - UI
#'
#' @description
#' Generates the user interface for the main analysis dashboard. This includes
#' the sidebar with dynamic filters, action buttons for running queries, and 
#' the main panel for displaying results.
#'
#' @details
#' The UI is namespaced using the \code{id} parameter to ensure it can exist 
#' alongside other modules without ID conflicts. It relies on the global 
#' \code{columns} and \code{display_names} variables defined in \code{global.R}.
#'
#' @param id Character string. The namespace identifier for this module.
#'           Must match the id passed to \code{analysisServer}.
#'
#' @return A \code{shiny::tagList} containing the sidebarLayout.
#'
#' @import shiny
#' @export
analysisUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    sidebarLayout(
      sidebarPanel(
        style = "background-color: #c2c2c2;",
        h3("API - POP"),
        actionButton(ns("upload_btn"), "Upload File"),
        
        h3("Filter by"),
        uiOutput(ns("filter_ui")), 
        
        div(class = "btn-container",
            actionButton(ns("run"), "Run Query", class = "btn-block"),
            actionButton(ns("reset"), "Reset Selections", class = "btn-block")
        ),
        
        selectInput(
          ns("pop_layer"),
          "Population Source:",
          choices = c("Select Location first" = ""),
          selected = ""
        ),
        
        div(class = "btn-container",
            downloadButton(ns("download_csv"), "Cases List", class = "btn-block"),
            downloadButton(ns("download_summary_csv"), "Weekly Summary", class = "btn-block")
        )
      ),
      mainPanel(
        tableOutput(ns("results"))
      )
    )
  )
}

#' @title Main Analysis Module - Server Logic
#'
#' @description
#' Handles the backend logic for the main analysis module. This includes:
#' \enumerate{
#'   \item \strong{Dynamic UI:} Rendering filters and geographic dropdowns.
#'   \item \strong{Query Execution:} Building SQL from inputs and fetching data.
#'   \item \strong{Downloads:} generating CSV reports.
#'   \item \strong{Uploads:} Parsing files and ingesting them into SQLite.
#' }
#'
#' @param id Character string. The namespace identifier.
#' @param con DBI Connection object.
#' @param gpkg_path Character string. Path to the geometry .gpkg file.
#'
#' @import shiny
#' @import DBI
#' @import RSQLite
#' @import dplyr
#' @import stringi
#' @importFrom tools file_ext toTitleCase
#' @importFrom readxl read_excel
#' @importFrom xml2 read_xml as_list
#' @export
analysisServer <- function(id, con, gpkg_path) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # ------------------------------------------------------------------
    # 1. DYNAMIC UI GENERATION (FILTERS)
    # ------------------------------------------------------------------
    output$filter_ui <- renderUI({
      req(exists("columns"), exists("display_names"))
      
      tagList(
        lapply(names(columns), function(col) {
          col_type <- columns[[col]]
          display <- if(col %in% names(display_names)) display_names[[col]] else col
          
          # Namespace IDs
          chk_id <- ns(paste0("chk_", col))
          val_id <- ns(paste0("val_", col))
          
          div(class = "filter-box",
              fluidRow(
                column(12, checkboxInput(chk_id, display, value = FALSE)),
                column(12,
                       conditionalPanel(
                         condition = paste0("input['", chk_id, "'] == true"),
                         tags$hr(),
                         
                         if(col_type == "geography") {
                           tagList(
                             # Initialize with first country if available
                             selectInput(ns("country"), "Configuration", choices = names(ALL_CONFIGS), selected = names(ALL_CONFIGS)[1]),
                             uiOutput(ns("geo_selectors")) 
                           )
                         } else if(col_type == "text") {
                           textInput(val_id, NULL, placeholder = paste("Enter", display))
                         } else if (col_type == "text_logic") {
                           tagList(
                             textInput(val_id, display, placeholder = paste("Enter", display)),
                             div(
                               actionButton(ns(paste0("btn_and_", col)), "AND"), 
                               actionButton(ns(paste0("btn_or_", col)), "OR")
                             ),
                             uiOutput(ns(paste0("preview_", col)))
                           )
                         } else if(col_type == "daterange") {
                           dateRangeInput(ns(paste0("valrange_", col)), paste("Select", display, "range"))
                         } else if(col_type == "date_or_range") {
                           tagList(
                             radioButtons(ns(paste0("mode_", col)), "Filter type", 
                                          choices = c("Exact" = "exact", "Range" = "range"), inline = TRUE),
                             conditionalPanel(
                               condition = paste0("input['", ns(paste0("mode_", col)), "'] == 'exact'"), 
                               dateInput(val_id, paste("Select", display))
                             ),
                             conditionalPanel(
                               condition = paste0("input['", ns(paste0("mode_", col)), "'] == 'range'"), 
                               dateRangeInput(ns(paste0("valrange_", col)), paste("Select", display, "range"))
                             )
                           )
                         } else if(col_type == "age") {
                           sliderInput(ns("age_range"), "Select Age range", min=0, max=120, value=c(0,120))
                         }
                       )
                )
              )
          )
        })
      )
    })
    
    # ------------------------------------------------------------------
    # 2. LOCATION LOGIC (RACE CONDITION FIX)
    # ------------------------------------------------------------------
    
    # A. Render Dropdowns (Pre-populated)
    # This prevents the empty dropdowns by fetching Level 1 data immediately upon rendering
    output$geo_selectors <- renderUI({
      
      # 1. Determine Country (Default to first if input not ready)
      selected_country <- if(isTruthy(input$country)) input$country else names(ALL_CONFIGS)[1]
      config <- tryCatch(ALL_CONFIGS[[selected_country]], error = function(e) NULL)
      
      # 2. Setup Default Labels & Empty Choices
      lbl1 <- "Level 1"; lbl2 <- "Level 2"; lbl3 <- "Level 3"
      choices1 <- c(""); choices2 <- c(""); choices3 <- c("")
      
      # 3. If Config is Valid, Fetch Level 1 Data NOW
      if(!is.null(config)) {
        if(length(config$levels) >= 2) {
          lbl1 <- tools::toTitleCase(config$levels[2])
          
          # Fetch options immediately to prevent race condition
          opts <- tryCatch({
            fetch_options(gpkg_path, selected_country, config$levels[2], parent_name = NULL, parent_val = NULL)
          }, error = function(e) character(0))
          
          choices1 <- c("", opts)
        }
        if(length(config$levels) >= 3) lbl2 <- tools::toTitleCase(config$levels[3])
        if(length(config$levels) >= 4) lbl3 <- tools::toTitleCase(config$levels[4])
      }
      
      # 4. Render Inputs with Data
      tagList(
        selectInput(ns("level1"), lbl1, choices = choices1),
        selectInput(ns("level2"), lbl2, choices = choices2),
        selectInput(ns("level3"), lbl3, choices = choices3)
      )
    })
    
    # B. Handle Population Layer Updates
    observeEvent(input$country, {
      req(input$country)
      if(exists("population_layers") && !is.null(population_layers[[input$country]])) {
        choices <- population_layers[[input$country]]
        updateSelectInput(session, "pop_layer", choices = choices, selected = choices[1])
      }
    }, ignoreInit = TRUE)
    
    # C. Update Level 2 (When Level 1 Changes)
    observeEvent(input$level1, {
      # Strict check: If Level 1 is empty, clear children and stop.
      if (!isTruthy(input$level1)) {
        updateSelectInput(session, "level2", choices = c(""))
        updateSelectInput(session, "level3", choices = c(""))
        return()
      }
      
      req(input$country)
      config <- ALL_CONFIGS[[input$country]]
      
      if(length(config$levels) >= 3) {
        opts <- tryCatch({
          fetch_options(gpkg_path, input$country, config$levels[3], 
                        parent_name = config$levels[2], parent_val = input$level1)
        }, error = function(e) return(character(0)))
        
        updateSelectInput(session, "level2", choices = c("", opts))
        updateSelectInput(session, "level3", choices = c("")) 
      }
    }, ignoreInit = TRUE)
    
    # D. Update Level 3 (When Level 2 Changes)
    observeEvent(input$level2, {
      # Strict check
      if (!isTruthy(input$level2)) {
        updateSelectInput(session, "level3", choices = c(""))
        return()
      }
      
      req(input$country)
      config <- ALL_CONFIGS[[input$country]]
      
      if(length(config$levels) >= 4) {
        opts <- tryCatch({
          fetch_options(gpkg_path, input$country, config$levels[4], 
                        parent_name = config$levels[3], parent_val = input$level2)
        }, error = function(e) return(character(0)))
        
        updateSelectInput(session, "level3", choices = c("", opts))
      }
    }, ignoreInit = TRUE)
    
    
    # ------------------------------------------------------------------
    # 3. FILTER LOGIC HELPERS
    # ------------------------------------------------------------------
    observe({
      lapply(names(columns)[columns == "text_logic"], function(col) {
        observeEvent(input[[paste0("btn_and_", col)]], {
          current <- input[[paste0("val_", col)]]; if (is.null(current)) current <- ""
          updateTextInput(session, paste0("val_", col), value = paste0(trimws(current), ifelse(current == "", "", " "), "and "))
        }, ignoreInit = TRUE)
        observeEvent(input[[paste0("btn_or_", col)]], {
          current <- input[[paste0("val_", col)]]; if (is.null(current)) current <- ""
          updateTextInput(session, paste0("val_", col), value = paste0(trimws(current), ifelse(current == "", "", " "), "or "))
        }, ignoreInit = TRUE)
        output[[paste0("preview_", col)]] <- renderUI({
          txt <- input[[paste0("val_", col)]]; if (is.null(txt) || txt == "") return(NULL)
          txt <- gsub("\\band\\b", "<span style='color:red;font-weight:bold'>and</span>", txt, ignore.case = TRUE)
          txt <- gsub("\\bor\\b", "<span style='color:red;font-weight:bold'>or</span>", txt, ignore.case = TRUE)
          HTML(txt)
        })
      })
    })
    
    # ------------------------------------------------------------------
    # 4. MAIN QUERY (WITH DB MAPPING)
    # ------------------------------------------------------------------
    data <- eventReactive(input$run, {
      eq_filters <- list(); range_filters <- list()
      normalize_input <- function(x) { if (is.character(x) && !is.null(x) && x != "") stringi::stri_trans_general(x, "Latin-ASCII") else x }
      
      # HELPER: Map Config Name (e.g., "province") to DB Name (e.g., "level1")
      get_db_col <- function(lvl_name) {
        if(is.null(input$country) || input$country == "") return(lvl_name)
        m <- ALL_CONFIGS[[input$country]]$mapping[[lvl_name]]
        if(!is.null(m) && !is.null(m$db_column)) return(m$db_column)
        return(lvl_name)
      }
      
      # 4.1 Collect Standard Filters
      for (col in names(columns)) {
        if (!isTRUE(input[[paste0("chk_", col)]])) next
        col_type <- columns[[col]]
        
        if (col_type %in% c("text", "text_logic")) {
          val <- normalize_input(input[[paste0("val_", col)]])
          if (!is.null(val) && val != "") eq_filters[[col]] <- val
        } else if (col_type == "daterange") {
          rng <- input[[paste0("valrange_", col)]]
          if (!is.null(rng) && length(rng) == 2) range_filters[[col]] <- as.Date(rng)
        } else if (col_type == "date_or_range") {
          mode <- input[[paste0("mode_", col)]]
          if (mode == "exact") {
            val <- normalize_input(input[[paste0("val_", col)]])
            if (!is.null(val) && val != "") eq_filters[[col]] <- as.Date(val)
          } else if (mode == "range") {
            rng <- input[[paste0("valrange_", col)]]
            if (!is.null(rng) && length(rng) == 2) range_filters[[col]] <- as.Date(rng)
          }
        }
      }
      
      # 4.2 Collect Geographic Filters (Using DB Names)
      if(isTruthy(input$country)) {
        config <- ALL_CONFIGS[[input$country]]
        eq_filters[["country"]] <- normalize_input(input$country)
        
        if(length(config$levels) >= 2 && isTruthy(input$level1)) eq_filters[[get_db_col(config$levels[2])]] <- normalize_input(input$level1)
        if(length(config$levels) >= 3 && isTruthy(input$level2)) eq_filters[[get_db_col(config$levels[3])]] <- normalize_input(input$level2)
        if(length(config$levels) >= 4 && isTruthy(input$level3)) eq_filters[[get_db_col(config$levels[4])]] <- normalize_input(input$level3)
      }
      
      # 4.3 Build SQL (With Aliasing)
      # We select "level1 AS province" so the UI displays nice names
      if(isTruthy(input$country)) {
        config <- ALL_CONFIGS[[input$country]]
        base_geo_cols <- sapply(config$levels, function(lvl) {
          db_name <- get_db_col(lvl)
          if(db_name != lvl) return(paste0(db_name, " AS ", lvl))
          return(db_name)
        })
      } else {
        base_geo_cols <- c("country")
      }
      
      select_cols <- c("suspected_diagnosis", "symptom_description", "symptom_onset_date", 
                       base_geo_cols, 
                       "consultation_date", "sex", "CAST((julianday(consultation_date) - julianday(birth_date)) / 365.25 AS INT) AS Age")
      
      sql <- paste("SELECT", paste(select_cols, collapse = ", "), 
                   "FROM", DBI::dbQuoteIdentifier(con, "reports"))
      
      sql <- add_filters_to_sql(sql, con, eq_filters, range_filters, input$age_range)
      result <- DBI::dbGetQuery(con, sql)
      to_utf8(result)
    })
    
    # ------------------------------------------------------------------
    # 5. OUTPUTS
    # ------------------------------------------------------------------
    output$results <- renderTable({
      req(data())
      df <- data()
      
      # --- ROBUST COLUMN SELECTION ---
      # 1. Start with the columns you WANT to show (from global.R)
      target_cols <- cols_for_table
      
      # 2. Also include any dynamic levels from the current country config
      #    (e.g., if the config produces "fraction", we want to show it)
      if (isTruthy(input$country) && exists("ALL_CONFIGS")) {
        config <- tryCatch(ALL_CONFIGS[[input$country]], error = function(e) NULL)
        if (!is.null(config)) {
          target_cols <- unique(c(target_cols, config$levels))
        }
      }
      
      # 3. INTERSECT: Only select columns that actually exist in the dataframe
      #    This is the "Safety Valve" that prevents the crash.
      valid_cols <- intersect(target_cols, names(df))
      
      df <- df[, valid_cols, drop = FALSE]
      
      # --- FIX ACCENTS ---
      # Fix accents for geographic columns if they exist
      geo_cols_to_fix <- intersect(c("country", "province", "department", "level1", "level2", "level3"), names(df))
      if (length(geo_cols_to_fix) > 0) df[geo_cols_to_fix] <- lapply(df[geo_cols_to_fix], fix_accents)
      
      # --- APPLY DISPLAY NAMES ---
      # Only rename columns that we actually have
      current_names <- colnames(df)
      new_names <- sapply(current_names, function(col) {
        if (col %in% names(display_names)) return(display_names[[col]])
        return(tools::toTitleCase(col)) # Fallback: Capitalize
      })
      colnames(df) <- new_names
      
      df
    }, sanitize.text.function = function(x) x)
    
    # ------------------------------------------------------------------
    # 6. UPLOAD HANDLER
    # ------------------------------------------------------------------
    raw_data <- reactiveVal(NULL)
    
    observeEvent(input$upload_btn, {
      showModal(modalDialog(
        title = "Upload File",
        fileInput(ns("file"), "Choose file", accept = c(".csv", ".xml", ".xlsx", ".dba")),
        footer = tagList(modalButton("Cancel"), actionButton(ns("confirm_upload"), "Upload"))
      ))
    })
    
    observeEvent(input$confirm_upload, {
      req(input$file)
      filepath <- input$file$datapath
      ext <- tools::file_ext(filepath)
      df <- switch(ext,
                   "csv"  = read.csv(filepath, stringsAsFactors = FALSE, fileEncoding = "UTF-8"),
                   "xlsx" = readxl::read_excel(filepath),
                   "xml"  = { doc <- xml2::read_xml(filepath); nodes <- xml2::as_list(doc); as.data.frame(do.call(rbind, lapply(nodes, unlist)), stringsAsFactors = FALSE) },
                   "dba"  = { tmp <- tempfile(fileext = ".sqlite"); file.copy(filepath, tmp, overwrite = TRUE); con2 <- DBI::dbConnect(RSQLite::SQLite(), tmp); df <- DBI::dbReadTable(con2, "reports"); DBI::dbDisconnect(con2); df },
                   stop("Unsupported file type")
      )
      df[] <- lapply(df, function(x) if (is.character(x)) iconv(x, from = "", to = "UTF-8", sub = "") else x)
      raw_data(df)
      showModal(modalDialog(
        title = "Map Columns",
        fluidRow(column(6, h4("File Columns")), column(6, h4("Reports Columns"))),
        uiOutput(ns("mapping_ui")),
        footer = tagList(modalButton("Cancel"), actionButton(ns("final_upload"), "Append Data"))
      ))
    })
    
    output$mapping_ui <- renderUI({
      req(raw_data())
      lapply(names(raw_data()), function(fc) {
        selectInput(ns(paste0("map_", fc)), label = fc, choices = c("", reports_cols), selected = if (fc %in% reports_cols) fc else "")
      })
    })
    
    observeEvent(input$final_upload, {
      df <- raw_data()
      mapping <- setNames(sapply(names(df), function(fc) input[[paste0("map_", fc)]]), names(df))
      for (fc in names(mapping)) if (mapping[[fc]] != "") names(df)[names(df) == fc] <- mapping[[fc]]
      df <- df[, unique(names(df)), drop = FALSE]
      for (col in setdiff(reports_cols, names(df))) df[[col]] <- NA
      df <- df[, reports_cols]
      
      DBI::dbAppendTable(con, "reports", df)
      # Ensure you updated this function in utils.R to match new DB names
      normalize_geography_batch(con, table = "reports", batch_size = 1000)
      
      removeModal()
      showNotification("Data merged into reports.")
    })
  })
}