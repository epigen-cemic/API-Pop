source("R/global.R")

ui <- fluidPage(
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "config.css")),
  div(class = "banner-container",
      img(src = "logoLeft.png", class = "banner-img fixed-img"),
      img(src = "logoMiddle.png", class = "banner-img flexible-img"),
      img(src = "logoRight.png", class = "banner-img fixed-img")
  ),

  sidebarLayout(
    sidebarPanel(style = "background-color: #c2c2c2;",
      titlePanel("Rumor Analisis"),
      actionButton("upload_btn", "Upload File"),
      
      h3("Filter by"),
      uiOutput("filter_ui"),
      div(class = "btn-container",
          actionButton("run", "Run Query", class = "btn-block"),
          actionButton("reset", "Reset Selections", class = "btn-block")
      ),
      
      selectInput(
        "pop_layer",
        "Population Source:",
        choices = c("Select Location first" = ""),
        selected = ""
      ),
      
      div(class = "btn-container",
          downloadButton("download_csv", "Entire Table", class = "btn-block"),
          downloadButton("download_summary_csv", "Weekly Summary", class = "btn-block")
          )
      ),
    mainPanel(
        tableOutput("results")
      )
    ),
  uiOutput("upload_modal")
  )



server <- function(input, output, session) {
  prov_data <- reactiveVal(NULL)
  dept_data <- reactiveVal(NULL)
  
  output$filter_ui <- renderUI({
    tagList(
      lapply(names(columns), function(col) {
        col_type <- columns[[col]]
        display <- if(col %in% names(display_names)) display_names[[col]] else col
        
        div(class = "filter-box",
            fluidRow(
              column(12, checkboxInput(paste0("chk_", col), display, value = FALSE)),
              column(12,
                     conditionalPanel(
                       condition = paste0("input.chk_", col, " == true"),
                       tags$hr(),
                       if(col_type == "text") {
                         textInput(paste0("val_", col), NULL, placeholder = paste("Enter", display))
                       } else if (col_type == "text_logic") {
                         tagList(
                           textInput(paste0("val_", col), display, placeholder = paste("Enter", display)),
                           div(
                             actionButton(paste0("btn_and_", col), "AND"),
                             actionButton(paste0("btn_or_", col), "OR")
                           ),
                           uiOutput(paste0("preview_", col))
                         )
                       } else if(col_type == "daterange") {
                         dateRangeInput(paste0("valrange_", col), paste("Select", display, "range"))
                       } else if(col_type == "date_or_range") {
                         tagList(
                           radioButtons(paste0("mode_", col), "Filter type",
                                        choices = c("Exact" = "exact", "Range" = "range"),
                                        inline = TRUE),
                           conditionalPanel(
                             condition = paste0("input.mode_", col, " == 'exact'"),
                             dateInput(paste0("val_", col), paste("Select", display))
                           ),
                           conditionalPanel(
                             condition = paste0("input.mode_", col, " == 'range'"),
                             dateRangeInput(paste0("valrange_", col), paste("Select", display, "range"))
                           )
                         )
                       } else if(col_type == "age") {      # new branch for age
                         sliderInput(paste0("valrange_", col),
                                     paste("Select", display, "range"),
                                     min = 0, max = 120, value = c(0, 120))
                       } else if(col_type == "geography") {
                         tagList(
                           selectInput("country", "Country", choices = c("", "Argentina", "Brazil")),
                           selectInput("province", "Province", choices = c("")),
                           selectInput("department", "Department", choices = c("")),
                           selectInput("fraction", "Censal Fraction", choices = c(""))
                         )
                       }
                     )
              )
            )
        )
      })
    )
  })

  observeEvent(input$country, {
    req(input$country) 
    
    prov_data_fetched <- get_info_about_country( 
      information = "nam, cpr", 
      layer_type = "prov", 
      country = input$country 
      )
    
    prov_data(prov_data_fetched)
    provinces <- sort(as.vector(prov_data()$nam))
    updateSelectInput(session, "province", choices = c("", provinces))
    updateSelectInput(session, "department", choices = "")
    updateSelectInput(session, "fraction", choices = "") 
    }) 
  
  observeEvent(input$province, {
    req(input$province, input$country) 
    province_cpr <- prov_data()$cpr[prov_data()$nam == input$province]
    
    dept_data_fetched <- get_info_about_country(
      information = "nam, cde", 
      layer_type = "dpto", 
      country = input$country, 
      type = "cpr", name = province_cpr 
      )
    
    dept_data(dept_data_fetched) 
    departments <- sort(as.vector(dept_data()$nam))
    updateSelectInput(session, "department", choices = c("", departments))
    updateSelectInput(session, "fraction", choices = "") 
    }) 
  
  observeEvent(input$department, { 
    req(input$department, input$province, input$country) 
    dept_cde <- dept_data()$cde[dept_data()$nam == input$department] 
    
    cod_indec_choices <- get_info_about_country( 
      information = "cod_indec", 
      layer_type = "fracc",
      country = input$country, 
      type = "cde", name = dept_cde 
      ) 
    
    cod_indec_choices <- sort(cod_indec_choices$cod_indec) 
    updateSelectInput(session, "fraction", choices = c("", cod_indec_choices)) 
    })
  
  observe({
    lapply(names(columns)[columns == "text_logic"], function(col) {

      observeEvent(input[[paste0("btn_and_", col)]], {
        current <- input[[paste0("val_", col)]]
        if (is.null(current)) current <- ""
        updateTextInput(session, paste0("val_", col),
                        value = paste0(trimws(current), ifelse(current == "", "", " "), "and "))
      }, ignoreInit = TRUE)      # AND button

      observeEvent(input[[paste0("btn_or_", col)]], {
        current <- input[[paste0("val_", col)]]
        if (is.null(current)) current <- ""
        updateTextInput(session, paste0("val_", col),
                        value = paste0(trimws(current), ifelse(current == "", "", " "), "or "))
      }, ignoreInit = TRUE)      # OR button
      
      output[[paste0("preview_", col)]] <- renderUI({
        txt <- input[[paste0("val_", col)]]
        if (is.null(txt) || txt == "") return(NULL)

        txt <- gsub("\\band\\b", "<span style='color:red;font-weight:bold'>and</span>",
                    txt, ignore.case = TRUE)
        txt <- gsub("\\bor\\b", "<span style='color:red;font-weight:bold'>or</span>",
                    txt, ignore.case = TRUE)
        HTML(txt)
      })      # Preview with AND/OR in red
    })
  })    # For symptoms logic filters
  
  data <- eventReactive(input$run, {
    eq_filters <- list()
    range_filters <- list()
    
    # existing loop over columns...
    for (col in names(columns)) {
      col_type <- columns[[col]]
      if (!isTRUE(input[[paste0("chk_", col)]])) next
      
      if (col_type == "text") {
        val <- input[[paste0("val_", col)]]
        if (!is.null(val) && val != "") eq_filters[[col]] <- val
      } else if (col_type == "text_logic") {
        val <- input[[paste0("val_", col)]]
        if (!is.null(val) && val != "") eq_filters[[col]] <- val
      } else if (col_type == "daterange") {
        rng <- input[[paste0("valrange_", col)]]
        if (!is.null(rng) && length(rng) == 2 && all(!is.na(rng)))
          range_filters[[col]] <- as.Date(rng)
      } else if (col_type == "date_or_range") {
        mode <- input[[paste0("mode_", col)]]
        if (mode == "exact") {
          val <- input[[paste0("val_", col)]]
          if (!is.null(val) && val != "") eq_filters[[col]] <- as.Date(val)
        } else if (mode == "range") {
          rng <- input[[paste0("valrange_", col)]]
          if (!is.null(rng) && length(rng) == 2 && all(!is.na(rng)))
            range_filters[[col]] <- as.Date(rng)
        }
      }
    }
    
    # Geography filters
    if (!is.null(input$country)    && input$country    != "") eq_filters[["country"]] <- stri_trans_general(input$country, "Latin-ASCII")
    if (!is.null(input$province)   && input$province   != "") eq_filters[["province"]] <- stri_trans_general(input$province, "Latin-ASCII")
    if (!is.null(input$department) && input$department != "") eq_filters[["department"]] <- stri_trans_general(input$department, "Latin-ASCII")
    if (!is.null(input$fraction)   && input$fraction   != "") eq_filters[["censal_fraction"]] <- input$fraction
    
    # Age filter
    age_range <- input$age_range
    
    # Build base query
    sql <- paste(
      "SELECT",
      paste(c(
        "suspected_diagnosis",
        "symptom_description",
        "symptom_onset_date",
        "country",
        "province",
        "department",
        "censal_fraction",
        "consultation_date",
        "sex",
        "CAST((julianday(consultation_date) - julianday(birth_date)) / 365.25 AS INT) AS Age"
      ), collapse = ", "),
      "FROM", dbQuoteIdentifier(con, table_name)
    )
    
    # Add filters
    sql <- add_filters_to_sql(sql, con, eq_filters, range_filters, age_range)
    
    # Run query
    result <- dbGetQuery(con, sql)
    result <- to_utf8(result)
    result
  })
  
  observeEvent(input$reset, {
    
    # Reset checkboxes and corresponding values
    for (col in names(columns)) {
      updateCheckboxInput(session, paste0("chk_", col), value = FALSE)
      
      col_type <- columns[[col]]
      
      if (col_type == "text" || col_type == "date_or_range") {
        updateTextInput(session, paste0("val_", col), value = "")
      }
      if (col_type == "daterange" || col_type == "date_or_range") {
        updateDateRangeInput(session, paste0("valrange_", col), start = NULL, end = NULL)
      }
      if (col_type == "date_or_range") {
        updateRadioButtons(session, paste0("mode_", col), selected = "exact")
      }
      if (col_type == "geography") {
        updateSelectInput(session, "country", selected = "")
        updateSelectInput(session, "province", choices = "", selected = "")
        updateSelectInput(session, "department", choices = "", selected = "")
        updateSelectInput(session, "fraction", choices = "", selected = "")
      }
      if (col_type == "age") {
        updateSliderInput(session, "age_range", value = c(0, 120))
    }
      }
    })
  
  output$results <- renderTable({
    df <- data()[, cols_for_table, drop = FALSE]
    colnames(df) <- display_names[cols_for_table]
    df
  })
  
  observeEvent(input$country, {
    req(input$country)
    choices <- population_layers[[input$country]]
    updateSelectInput(session, "pop_layer", choices = choices, selected = choices[1])
  })
  
  output$download_summary_csv <- downloadHandler(filename = function() {
      paste0("weekly_summary_", Sys.Date(), ".csv")
    },
      content = function(file) {
      df <- data()
      req(df)
      df <- df %>%
        mutate(week = strftime(as.Date(consultation_date), format = "%Y-%U"))
      summary_df <- df %>%
        group_by(week, censal_fraction) %>%
        summarise(recount = n(), .groups = "drop")
      summary_df <- summary_df %>%
        mutate(censal_fraction = sprintf("%07s", censal_fraction))
      censal_fractions_choices <- unique(summary_df$censal_fraction)
      if(length(censal_fractions_choices) == 0) censal_fractions_choices <- NA

      library(sf)
      gpkg_file <- here("data", "geometry.gpkg")
      layer_name <- "fracc_argentina"  # adjust to your country/layer
      pop_df <- st_read(gpkg_file, layer = layer_name, quiet = TRUE) %>%
        st_drop_geometry() %>%
        filter(sprintf("%07s", cod_indec) %in% censal_fractions_choices) %>%
        mutate(cod_indec = sprintf("%07s", cod_indec)) %>%
        rename(
          censal_fraction = cod_indec,
          total_population = Population
        )
      summary_df <- summary_df %>%
        left_join(pop_df, by = "censal_fraction")
      if(!"total_population" %in% colnames(summary_df)) {
        summary_df$total_population <- NA
      }
      summary_df <- summary_df %>%
        select(week, censal_fraction, recount, total_population)
      write.csv(summary_df, file, row.names = FALSE, fileEncoding = "UTF-8")
    })

  output$download_csv <- downloadHandler(filename = function() {
      paste0("query_results_", Sys.Date(), ".csv")
    },
    content = function(file) {
      df <- data()   # your reactive with the query results
      if(!is.null(df)) {
        write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    })
  
  ### File Upload ### optimization pending
  observeEvent(input$upload_btn, {
    showModal(modalDialog(
      title = "Upload File",
      fileInput("file", "Choose file", 
                accept = c(".csv", ".xml", ".xlsx", ".dba")),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_upload", "Upload")
      )
    ))
  })
  
  observeEvent(input$confirm_upload, {
    req(input$file)
    filepath <- input$file$datapath
    ext <- tools::file_ext(filepath)
    
    df <- switch(ext,
                 "csv"  = read.csv(filepath, stringsAsFactors = FALSE),
                 "xlsx" = read_excel(filepath),
                 "xml"  = {
                   doc <- read_xml(filepath)
                   as.data.frame(as.list(xml_text(xml_find_all(doc, "//*")))) # adapt
                 },
                 "dba"  = {
                   con2 <- dbConnect(RSQLite::SQLite(), filepath)
                   df <- dbReadTable(con2, "reports")
                   dbDisconnect(con2)
                   df
                 },
                 stop("Unsupported file type")
    )
    raw_data(df)
    
    showModal(modalDialog(
      title = "Map Columns",
      fluidRow(
        column(6, h4("File Columns")),
        column(6, h4("Reports Columns"))
      ),
      uiOutput("mapping_ui"),
      footer = tagList(modalButton("Cancel"),
                       actionButton("final_upload", "Append Data"))
    ))
  })
  
  output$mapping_ui <- renderUI({
    req(raw_data())
    file_cols <- names(raw_data())
    lapply(file_cols, function(fc) {
      selectInput(paste0("map_", fc),
                  label = fc,
                  choices = c("", reports_cols),
                  selected = if (fc %in% reports_cols) fc else "")
    })
  })
  
  observeEvent(input$final_upload, {
    df <- raw_data()
    mapping <- setNames(
      sapply(names(df), function(fc) input[[paste0("map_", fc)]]),
      names(df)
    )
    for (fc in names(mapping)) {
      if (mapping[[fc]] != "") {
        names(df)[names(df) == fc] <- mapping[[fc]]
      }
    }
    df <- df[, unique(names(df)), drop = FALSE]
    for (col in setdiff(reports_cols, names(df))) {
      df[[col]] <- NA
    }
    df <- df[, reports_cols]
    
    dbAppendTable(con, "reports", df)
    
    removeModal()
    showNotification("Data merged into reports.")
  })
  
  onStop(function() dbDisconnect(con))
}




shinyApp(ui = ui, server = server)
