uploadUI <- function(id) {
  ns <- NS(id)
  actionButton(ns("upload_btn"), "Upload File")
}

uploadServer <- function(id, con, reports_cols) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    raw_data <- reactiveVal(NULL)
    
    # 1. Open Upload Modal
    observeEvent(input$upload_btn, {
      showModal(modalDialog(
        title = "Upload File",
        fileInput(ns("file"), "Choose file", accept = c(".csv", ".xml", ".xlsx", ".dba")),
        footer = tagList(modalButton("Cancel"), actionButton(ns("confirm_upload"), "Upload"))
      ))
    })
    
    # 2. Process File
    observeEvent(input$confirm_upload, {
      req(input$file)
      filepath <- input$file$datapath
      ext <- tools::file_ext(filepath)
      
      df <- switch(ext,
                   "csv"  = read.csv(filepath, stringsAsFactors = FALSE, fileEncoding = "UTF-8"),
                   "xlsx" = readxl::read_excel(filepath),
                   "xml"  = {
                     doc <- xml2::read_xml(filepath); nodes <- xml2::as_list(doc)
                     as.data.frame(do.call(rbind, lapply(nodes, unlist)), stringsAsFactors = FALSE)
                   },
                   "dba"  = {
                     tmp <- tempfile(fileext = ".sqlite"); file.copy(filepath, tmp, overwrite = TRUE)
                     con2 <- DBI::dbConnect(RSQLite::SQLite(), tmp); df <- DBI::dbReadTable(con2, "reports")
                     DBI::dbDisconnect(con2); df
                   },
                   stop("Unsupported file type")
      )
      
      # Clean encoding
      df[] <- lapply(df, function(x) if (is.character(x)) iconv(x, from = "", to = "UTF-8", sub = "") else x)
      raw_data(df)
      
      # Show Mapping Modal
      showModal(modalDialog(
        title = "Map Columns",
        fluidRow(column(6, h4("File Columns")), column(6, h4("Reports Columns"))),
        uiOutput(ns("mapping_ui")),
        footer = tagList(modalButton("Cancel"), actionButton(ns("final_upload"), "Append Data"))
      ))
    })
    
    # 3. Dynamic Mapping UI
    output$mapping_ui <- renderUI({
      req(raw_data())
      lapply(names(raw_data()), function(fc) {
        selectInput(ns(paste0("map_", fc)), label = fc, choices = c("", reports_cols), 
                    selected = if (fc %in% reports_cols) fc else "")
      })
    })
    
    # 4. Final Append
    observeEvent(input$final_upload, {
      df <- raw_data()
      # Rename columns based on mapping
      mapping <- setNames(sapply(names(df), function(fc) input[[paste0("map_", fc)]]), names(df))
      for (fc in names(mapping)) if (mapping[[fc]] != "") names(df)[names(df) == fc] <- mapping[[fc]]
      
      # Match DB structure
      df <- df[, unique(names(df)), drop = FALSE]
      for (col in setdiff(reports_cols, names(df))) df[[col]] <- NA
      df <- df[, reports_cols]
      
      DBI::dbAppendTable(con, "reports", df)
      normalize_geography_batch(con, table = "reports", batch_size = 1000)
      
      removeModal()
      showNotification("Data merged into reports successfully.", type = "message")
    })
  })
}