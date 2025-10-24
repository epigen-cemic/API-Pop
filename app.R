source("R/global.R")

ui <- fluidPage(
  tags$head(
    tags$title("API Population "),
    tags$link(rel = "stylesheet", type = "text/css", href = "config.css")),
  div(class = "banner-container",
      img(src = "logoLeft.png", class = "banner-img fixed-img"),
      img(src = "logoMiddle.png", class = "banner-img flexible-img"),
      img(src = "logoRight.png", class = "banner-img fixed-img")
  ),

  sidebarLayout(
    sidebarPanel(style = "background-color: #c2c2c2;",
      titlePanel("API - POP"),
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
          downloadButton("download_csv", "Cases List", class = "btn-block"),
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
                         sliderInput("age_range", "Select Age range", min=0, max=120, value=c(0,120))
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
  })   # Reactive UI

  ### Location Inputs ###
  
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
  
  # server.R or inline in your server
  
  data <- eventReactive(input$run, {
    eq_filters <- list()
    range_filters <- list()
    
    # Function to normalize inputs once
    normalize_input <- function(x) {
      if (is.character(x) && !is.null(x) && x != "") {
        stri_trans_general(x, "Latin-ASCII")
      } else x
    }
    
    for (col in names(columns)) {
      col_type <- columns[[col]]
      if (!isTRUE(input[[paste0("chk_", col)]])) next
      
      if (col_type %in% c("text", "text_logic")) {
        val <- input[[paste0("val_", col)]]
        val <- normalize_input(val)
        if (!is.null(val) && val != "") eq_filters[[col]] <- val
      } else if (col_type == "daterange") {
        rng <- input[[paste0("valrange_", col)]]
        if (!is.null(rng) && length(rng) == 2 && all(!is.na(rng)))
          range_filters[[col]] <- as.Date(rng)
      } else if (col_type == "date_or_range") {
        mode <- input[[paste0("mode_", col)]]
        if (mode == "exact") {
          val <- input[[paste0("val_", col)]]
          val <- normalize_input(val)
          if (!is.null(val) && val != "") eq_filters[[col]] <- as.Date(val)
        } else if (mode == "range") {
          rng <- input[[paste0("valrange_", col)]]
          if (!is.null(rng) && length(rng) == 2 && all(!is.na(rng)))
            range_filters[[col]] <- as.Date(rng)
        }
      }
    }
    
    # Geography filters
    geo_cols <- c("country", "province", "department", "censal_fraction")
    for (col in geo_cols) {
      val <- input[[col]]
      val <- normalize_input(val)
      if (!is.null(val) && val != "") eq_filters[[col]] <- val
    }
    
    # Age filter
    age_range <- input$age_range
    
    # Build SQL
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
    
    sql <- add_filters_to_sql(sql, con, eq_filters, range_filters, age_range)
    
    result <- dbGetQuery(con, sql)
    result <- to_utf8(result)
    result
  })    # Query format
  
  observeEvent(input$reset, {
    for (col in names(columns)) {
      updateCheckboxInput(session, paste0("chk_", col), value = FALSE)
      
      col_type <- columns[[col]]
      
      if (col_type %in% c("text", "date_or_range")) {
        updateTextInput(session, paste0("val_", col), value = "")
      }
      if (col_type %in% c("daterange", "date_or_range")) {
        updateDateRangeInput(session, paste0("valrange_", col),
                             start = NULL, end = NULL)
      }
      if (col_type == "date_or_range") {
        updateRadioButtons(session, paste0("mode_", col), selected = "exact")
      }
      if (col_type == "geography") {
        updateSelectInput(session, "country", selected = "")
        updateSelectInput(session, "province", choices = character(0), selected = "")
        updateSelectInput(session, "department", choices = character(0), selected = "")
        updateSelectInput(session, "fraction", choices = character(0), selected = "")
      }
      if (col_type == "age") {
        isolate(updateSliderInput(session, "age_range", value = c(0, 120)))
      }
    }
    if (exists("data")) try(data(NULL), silent = TRUE)
  })  # Query reset
  
  output$results <- renderTable({
    df <- data()[, cols_for_table, drop = FALSE]
    geo_cols <- intersect(c("country", "province", "department"), names(df))
    if (length(geo_cols) > 0) {
      df[geo_cols] <- lapply(df[geo_cols], fix_accents)
    }
    
    colnames(df) <- display_names[cols_for_table]
    df
  }, sanitize.text.function = function(x) x)  # Table With results
  
  observeEvent(input$country, {
    req(input$country)
    choices <- population_layers[[input$country]]
    updateSelectInput(session, "pop_layer", choices = choices, selected = choices[1])
  })      # Database with population
  
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
        mutate(
          country = input$country,
          province = input$province,
          department = input$department
        ) %>%
        select(week, country, province, department, censal_fraction, recount, total_population)
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
                 "csv"  = read.csv(filepath, stringsAsFactors = FALSE, fileEncoding = "UTF-8"),
                 "xlsx" = readxl::read_excel(filepath),
                 "xml"  = {
                   doc <- xml2::read_xml(filepath)
                   nodes <- xml2::as_list(doc)
                   as.data.frame(do.call(rbind, lapply(nodes, unlist)), stringsAsFactors = FALSE)
                 },
                 "dba"  = {
                   tmp <- tempfile(fileext = ".sqlite")
                   file.copy(filepath, tmp, overwrite = TRUE)
                   con2 <- DBI::dbConnect(RSQLite::SQLite(), tmp)
                   df <- DBI::dbReadTable(con2, "reports")
                   DBI::dbDisconnect(con2)
                   df
                 },
                 stop("Unsupported file type")
    )
    
    df[] <- lapply(df, function(x)
      if (is.character(x)) iconv(x, from = "", to = "UTF-8", sub = "") else x
    )
    
    raw_data(df)
    showModal(modalDialog(
      title = "Map Columns",
      fluidRow(
        column(6, h4("File Columns")),
        column(6, h4("Reports Columns"))
      ),
      uiOutput("mapping_ui"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("final_upload", "Append Data")
      )
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
    normalize_geography_batch(con, table = "reports", batch_size = 1000)
    
    removeModal()
    showNotification("Data merged into reports.")
  })
  
  onStop(function() dbDisconnect(con))
}




shinyApp(ui = ui, server = server)
