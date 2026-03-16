#' Upload Module UI
#'
#' Generates the user interface for the data upload module, consisting 
#' of a single action button to trigger the upload modal.
#'
#' @param id Character string. The namespace ID for the Shiny module.
#' @return A Shiny UI `actionButton`.
#' @export
uploadUI <- function(id) {
  ns <- NS(id)
  actionButton(ns("upload_btn"), "Upload File")
}

#' Upload Module Server
#'
#' Handles the server-side logic for uploading files (CSV, XLSX, XML, SQLite/DBA),
#' mapping columns to the database schema, appending the data, and triggering 
#' geographic normalization.
#'
#' @param id Character string. The Shiny module ID.
#' @param con A DBIConnection object (or pool).
#' @param target_table Character string. The name of the database table to append data to.
#' @param target_cols Character vector. The expected columns in the target database table.
#' @return NULL
#' @export
uploadServer <- function(id, con, target_table = "reports", target_cols) {
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
                   "csv"  = {
                     tryCatch({
                       utils::read.csv(filepath, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
                     }, warning = function(w) {
                       utils::read.csv(filepath, stringsAsFactors = FALSE, fileEncoding = "latin1")
                     }, error = function(e) {
                       utils::read.csv(filepath, stringsAsFactors = FALSE, fileEncoding = "latin1")
                     })
                   },
                   "xlsx" = readxl::read_excel(filepath),
                   "xlsx" = readxl::read_excel(filepath),
                   "xml"  = {
                     doc <- xml2::read_xml(filepath); nodes <- xml2::as_list(doc)
                     as.data.frame(do.call(rbind, lapply(nodes, unlist)), stringsAsFactors = FALSE)
                   },
                   "dba"  = {
                     tmp <- tempfile(fileext = ".sqlite"); file.copy(filepath, tmp, overwrite = TRUE)
                     con2 <- DBI::dbConnect(RSQLite::SQLite(), tmp); df <- DBI::dbReadTable(con2, target_table)
                     DBI::dbDisconnect(con2); df
                   },
                   stop("Unsupported file type")
      )
      
      # Clean encoding and fix common mojibake using global fix_map
      df[] <- lapply(df, function(x) {
        if (is.character(x)) {
          x <- enc2utf8(as.character(x))
          x <- fix_accents(x)
          return(x)
        } else {
          return(x)
        }
      })
      raw_data(df)
      
      # Show Mapping Modal
      showModal(modalDialog(
        title = "Map Columns",
        uiOutput(ns("mapping_ui")),
        footer = tagList(modalButton("Cancel"), actionButton(ns("final_upload"), "Append Data"))
      ))
    })
    
    # 3. Dynamic Mapping UI (SMART MAPPING)
    output$mapping_ui <- renderUI({
      req(raw_data())
      df_cols <- names(raw_data())
      
      # Find columns that do NOT exactly match the database columns
      unmatched_cols <- setdiff(df_cols, target_cols)
      
      # If everything matches perfectly, just show a success message!
      if (length(unmatched_cols) == 0) {
        return(tags$div(
          class = "alert alert-success",
          style = "background-color: #d4edda; color: #155724; padding: 15px; border-radius: 5px; border: 1px solid #c3e6cb;",
          strong("Success!"), " All columns in your file match the database perfectly. Click 'Append Data' to proceed."
        ))
      }
      
      # Otherwise, only ask about the unmatched columns
      tagList(
        p("The following columns from your file did not match automatically. Please map them to the database, or leave blank to ignore them:"),
        tags$hr(),
        fluidRow(column(6, h5(strong("Your File"))), column(6, h5(strong("Database")))),
        lapply(unmatched_cols, function(fc) {
          fluidRow(
            column(6, p(fc, style = "margin-top: 8px;")),
            column(6, selectInput(ns(paste0("map_", fc)), label = NULL, choices = c("(Ignore)" = "", target_cols), selected = ""))
          )
        })
      )
    })
    
    # 4. Final Append
    observeEvent(input$final_upload, {
      df <- raw_data()
      req(nrow(df) > 0)
      df_cols <- names(df)
      unmatched_cols <- setdiff(df_cols, target_cols)
      
      # Rename ONLY the unmatched columns based on what the user selected in the UI
      for (fc in unmatched_cols) {
        mapped_val <- input[[paste0("map_", fc)]]
        if (!is.null(mapped_val) && mapped_val != "") {
          names(df)[names(df) == fc] <- mapped_val
        }
      }
      
      # Strip out any columns from the uploaded file that still don't map to the DB
      df <- df[, names(df) %in% target_cols, drop = FALSE]
      
      # Add missing database columns to the dataframe as NA
      for (col in setdiff(target_cols, names(df))) {
        df[[col]] <- NA
      }
      
      # Reorder columns to exactly match the database table structure
      df <- df[, target_cols, drop = FALSE]
      
      # Append and Normalize
      pool::dbAppendTable(con, target_table, df)
      normalize_geography_batch(con, table = target_table, batch_size = 1000)
      
      removeModal()
      showNotification(paste("Data merged into", target_table, "successfully."), type = "message")
    })
  })
}