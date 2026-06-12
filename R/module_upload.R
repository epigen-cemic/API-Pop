#' Upload Module UI
#'
#' Generates the user interface for the data upload module.
#'
#' The module supports multiple files, stages them for review, marks unreadable
#' or empty files as disallowed, and lets users append only the active allowed
#' files to the configured active data source.
#'
#' @param id Character string. The namespace ID for the Shiny module.
#' @return A Shiny UI `tagList`.
#' @export
uploadUI <- function(id) {
  ns <- NS(id)

  tagList(
    uiOutput(ns("data_source_notice")),
    actionButton(ns("upload_btn"), "Upload Files", class = "btn-block upload-primary-btn"),
    uiOutput(ns("upload_status_summary"))
  )
}

#' Upload Module Server
#'
#' Handles the server-side logic for uploading files (CSV, XLSX, XML,
#' SQLite/DBA), staging them for review, mapping columns to the app data fields,
#' appending the active data, and triggering geographic normalization.
#'
#' @param id Character string. The Shiny module ID.
#' @param con A DBIConnection object or pool.
#' @param target_table Character string. The database table to append data to.
#' @param target_cols Character vector. The expected columns in the target table.
#' @param data_source_settings Optional list describing the active data source.
#' @return NULL
#' @export
uploadServer <- function(id, con, target_table = "reports", target_cols, data_source_settings = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    raw_data <- reactiveVal(NULL)
    staged_files <- reactiveVal(list())
    upload_log <- reactiveVal(staged_upload_summary(list()))

    output$data_source_notice <- renderUI({
      settings <- data_source_settings %||% list()
      mode <- settings$mode %||% "local"
      is_external <- identical(mode, "external_database") || identical(mode, "external")

      upload_enabled <- isTRUE(settings$upload_enabled %||% TRUE)
      source_text <- if (is_external) {
        "Using an external data source. File uploads remain available and append to the active data source."
      } else {
        "Using local uploaded data. You can add more files at any time."
      }
      upload_text <- if (upload_enabled) {
        paste(
          "Accepted upload formats:",
          paste(toupper(supported_upload_extensions()), collapse = ", ")
        )
      } else {
        "File uploads are disabled in this configuration."
      }

      tags$div(
        class = "data-source-notice",
        tags$strong("Data source"),
        tags$span(source_text),
        tags$small(upload_text)
      )
    })

    output$upload_status_summary <- renderUI({
      log_df <- upload_log()
      if (is.null(log_df) || nrow(log_df) == 0) {
        return(tags$small(class = "filter-help-text", "No files uploaded in this session."))
      }

      allowed <- sum(grepl("^Allowed|Appended", log_df$Status), na.rm = TRUE)
      total <- nrow(log_df)

      div(
        class = "upload-status-row",
        tags$small(
          class = "filter-help-text upload-status-summary",
          paste("Last reviewed files:", total, "| Allowed/appended:", allowed)
        ),
        actionButton(
          ns("show_upload_log"),
          "Review uploaded files",
          class = "btn btn-default btn-xs upload-review-btn"
        )
      )
    })

    output$upload_log <- DT::renderDT({
      log_df <- upload_log()
      if (is.null(log_df) || nrow(log_df) == 0) {
        return(app_datatable(data.frame(Message = "No uploaded files yet."), page_length = 5))
      }

      app_datatable(log_df, page_length = 5)
    })

    observeEvent(input$show_upload_log, {
      showModal(modalDialog(
        title = "Uploaded Files Review",
        tags$p(
          class = "upload-modal-help",
          "This review only shows files handled in the current session. It does not expose the internal storage used by the app."
        ),
        DT::DTOutput(ns("upload_log")),
        footer = modalButton("Close"),
        size = "l",
        easyClose = TRUE
      ))
    })

    # 1. Open Upload Modal
    observeEvent(input$upload_btn, {
      settings <- data_source_settings %||% list()
      if (!isTRUE(settings$upload_enabled %||% TRUE)) {
        showNotification("File uploads are disabled in this configuration.", type = "warning")
        return()
      }

      showModal(modalDialog(
        title = "Upload Files",
        fileInput(
          ns("file"),
          "Choose one or more files",
          multiple = TRUE,
          accept = paste0(".", supported_upload_extensions())
        ),
        tags$p(
          class = "upload-modal-help",
          paste0(
            "Files are staged first. Empty, unreadable, or unsupported files are kept visible but cannot be appended. Accepted formats: ",
            paste(toupper(supported_upload_extensions()), collapse = ", "),
            "."
          )
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_upload"), "Review Files")
        ),
        size = "l",
        easyClose = TRUE
      ))
    })

    read_one_upload <- function(file_row, idx) {
      file_name <- as.character(file_row$name)
      file_path <- as.character(file_row$datapath)
      file_size <- suppressWarnings(as.numeric(file_row$size))
      ext <- tolower(tools::file_ext(file_name))
      item_id <- paste0("upload_", idx)

      if (!ext %in% supported_upload_extensions()) {
        return(list(
          id = item_id,
          name = file_name,
          size = file_size,
          ext = ext,
          data = NULL,
          rows = 0L,
          date_range = "",
          allowed = FALSE,
          status = "Disallowed",
          message = paste("Unsupported file type:", ext)
        ))
      }

      tryCatch({
        read_ext <- if (ext %in% c("sqlite", "db")) "dba" else ext
        df <- as.data.frame(read_uploaded_file(file_path, read_ext, target_table), stringsAsFactors = FALSE)
        validation <- validate_staged_upload(df, target_cols)

        list(
          id = item_id,
          name = file_name,
          size = file_size,
          ext = ext,
          data = df,
          rows = nrow(df),
          date_range = get_case_date_range(df),
          allowed = isTRUE(validation$allowed),
          status = validation$status,
          message = validation$message
        )
      }, error = function(e) {
        list(
          id = item_id,
          name = file_name,
          size = file_size,
          ext = ext,
          data = NULL,
          rows = 0L,
          date_range = "",
          allowed = FALSE,
          status = "Disallowed",
          message = paste("Read error:", conditionMessage(e))
        )
      })
    }

    # 2. Stage and review files
    observeEvent(input$confirm_upload, {
      req(input$file)

      staged <- lapply(seq_len(nrow(input$file)), function(i) {
        read_one_upload(input$file[i, , drop = FALSE], i)
      })
      names(staged) <- vapply(staged, function(item) item$id, character(1))
      staged_files(staged)
      upload_log(staged_upload_summary(staged))

      allowed_ids <- names(staged)[vapply(staged, function(item) isTRUE(item$allowed), logical(1))]
      allowed_choices <- stats::setNames(
        allowed_ids,
        vapply(staged[allowed_ids], function(item) item$name, character(1))
      )

      showModal(modalDialog(
        title = "Review Uploaded Files",
        if (length(allowed_ids) > 0) {
          checkboxGroupInput(
            ns("active_upload_ids"),
            "Active files to append",
            choices = allowed_choices,
            selected = allowed_ids
          )
        } else {
          div(class = "alert alert-warning", "No uploaded files are eligible to append.")
        },
        DT::DTOutput(ns("upload_review")),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(
            ns("prepare_upload"),
            "Continue to Mapping",
            class = "btn-primary",
            disabled = length(allowed_ids) == 0
          )
        ),
        size = "l",
        easyClose = TRUE
      ))
    })

    output$upload_review <- DT::renderDT({
      app_datatable(staged_upload_summary(staged_files()), page_length = 10)
    })

    # 3. Combine active files and show mapping modal
    observeEvent(input$prepare_upload, {
      active_ids <- input$active_upload_ids
      if (is.null(active_ids) || length(active_ids) == 0) {
        showNotification("Select at least one allowed file before continuing.", type = "warning")
        return()
      }

      df <- active_staged_uploads(staged_files(), active_ids)
      if (is.null(df) || nrow(df) == 0) {
        showNotification("No active rows are available to append.", type = "error")
        return()
      }

      raw_data(df)

      showModal(modalDialog(
        title = "Map Columns",
        uiOutput(ns("mapping_ui")),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("final_upload"), "Append Active Files")
        ),
        size = "l",
        easyClose = TRUE
      ))
    })

    # 4. Dynamic Mapping UI
    output$mapping_ui <- renderUI({
      req(raw_data())
      df_cols <- names(raw_data())

      helper_cols <- c("upload_file_id")
      unmatched_cols <- setdiff(df_cols, c(target_cols, helper_cols))

      if (length(unmatched_cols) == 0) {
        return(tags$div(
          class = "alert alert-success",
          strong("Success!"),
          " All active-file columns match the app data fields. Click 'Append Active Files' to proceed."
        ))
      }

      tagList(
        p("The following columns did not match automatically. Map them to app data fields or leave blank to ignore them:"),
        tags$hr(),
        fluidRow(column(6, h5(strong("Uploaded column"))), column(6, h5(strong("App data field")))),
        lapply(unmatched_cols, function(fc) {
          fluidRow(
            column(6, p(fc, style = "margin-top: 8px;")),
            column(
              6,
              selectInput(
                ns(paste0("map_", make.names(fc))),
                label = NULL,
                choices = c("(Ignore)" = "", target_cols),
                selected = ""
              )
            )
          )
        })
      )
    })

    # 5. Final Append
    observeEvent(input$final_upload, {
      df <- raw_data()
      req(nrow(df) > 0)

      helper_cols <- c("upload_file_id")
      unmatched_cols <- setdiff(names(df), c(target_cols, helper_cols))

      for (fc in unmatched_cols) {
        mapped_val <- input[[paste0("map_", make.names(fc))]]
        if (!is.null(mapped_val) && mapped_val != "") {
          names(df)[names(df) == fc] <- mapped_val
        }
      }

      df <- df[, names(df) %in% target_cols, drop = FALSE]
      df <- apply_code_length_rules(df, ALL_CONFIGS)
      df <- add_geographic_norm_columns(df)

      for (col in setdiff(target_cols, names(df))) {
        df[[col]] <- NA
      }
      df <- df[, target_cols, drop = FALSE]

      validation_message <- validate_database_ready_upload(df)
      if (!is.null(validation_message)) {
        showNotification(validation_message, type = "error", duration = 8)
        return()
      }

      pool::dbAppendTable(con, target_table, df)

      current_log <- staged_upload_summary(staged_files())
      if (nrow(current_log) > 0) {
        active_names <- vapply(
          staged_files()[input$active_upload_ids],
          function(item) item$name,
          character(1)
        )
        current_log$Status <- ifelse(current_log$File %in% active_names, "Appended", current_log$Status)
        upload_log(current_log)
      }

      removeModal()
      showNotification(
        paste(nrow(df), "rows appended successfully."),
        type = "message"
      )
    })
  })
}
