filtersUI <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("filter_ui")),
    div(class = "btn-container",
        actionButton(ns("run"), "Run Query", class = "btn-block"),
        actionButton(ns("reset"), "Reset Selections", class = "btn-block")
    ),
    selectInput(ns("pop_layer"), "Population Source:", choices = c("Select Location first" = ""), selected = "")
  )
}

filtersServer <- function(id, gpkg_path, columns, display_names, population_layers) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # --- 1. Render Dynamic Filters ---
    output$filter_ui <- renderUI({
      tagList(
        lapply(names(columns), function(col) {
          col_type <- columns[[col]]
          display <- if(col %in% names(display_names)) display_names[[col]] else col
          
          div(class = "filter-box",
              fluidRow(
                column(12, checkboxInput(ns(paste0("chk_", col)), display, value = FALSE)),
                column(12,
                       conditionalPanel(
                         condition = paste0("input['", ns(paste0("chk_", col)), "'] == true"),
                         tags$hr(),
                         if(col_type == "text") {
                           textInput(ns(paste0("val_", col)), NULL, placeholder = paste("Enter", display))
                         } 
                         else if (col_type == "text_logic") {
                           tagList(
                             textInput(ns(paste0("val_", col)), display, placeholder = paste("Enter", display)),
                             div(actionButton(ns(paste0("btn_and_", col)), "AND"), actionButton(ns(paste0("btn_or_", col)), "OR")),
                             uiOutput(ns(paste0("preview_", col)))
                           )
                         } 
                         else if(col_type == "date_or_range") {
                           tagList(
                             radioButtons(ns(paste0("mode_", col)), "Filter type", choices = c("Exact" = "exact", "Range" = "range"), inline = TRUE),
                             conditionalPanel(condition = paste0("input['", ns(paste0("mode_", col)), "'] == 'exact'"), dateInput(ns(paste0("val_", col)), paste("Select", display))),
                             conditionalPanel(condition = paste0("input['", ns(paste0("mode_", col)), "'] == 'range'"), dateRangeInput(ns(paste0("valrange_", col)), paste("Select", display, "range")))
                           )
                         } 
                         else if(col_type == "age") {
                           sliderInput(ns("age_range"), "Select Age range", min=0, max=120, value=c(0,120))
                         } 
                         else if(col_type == "geography") {
                           tagList(
                             selectInput(ns("country"), "Country", choices = c("", "Argentina", "Brazil")),
                             selectInput(ns("province"), "Province", choices = c("")),
                             selectInput(ns("department"), "Department", choices = c("")),
                             selectInput(ns("fraction"), "Censal Fraction", choices = c(""))
                           )
                         }
                       )
                )
              )
          )
        })
      )
    })
    
    # --- 2. Location Cascading Logic ---
    observeEvent(input$country, {
      req(input$country)
      
      # FIX: Removed "reports" argument
      provinces <- fetch_options(gpkg_path, input$country, "province")
      
      updateSelectInput(session, "province", choices = c("", provinces))
      updateSelectInput(session, "department", choices = "")
      updateSelectInput(session, "fraction", choices = "")
      
      pop_choices <- population_layers[[input$country]]
      updateSelectInput(session, "pop_layer", choices = pop_choices, selected = pop_choices[1])
    })
    
    observeEvent(input$province, {
      req(input$province, input$country)
      
      # FIX: Removed "reports" argument
      departments <- fetch_options(gpkg_path, input$country, "department", 
                                   parent_name = "province", parent_val = input$province)
      
      updateSelectInput(session, "department", choices = c("", departments))
      updateSelectInput(session, "fraction", choices = "")
    })
    
    observeEvent(input$department, {
      req(input$department, input$province, input$country)
      
      # FIX: Removed "reports" argument
      fractions <- fetch_options(gpkg_path, input$country, "fraction", 
                                 parent_name = "department", parent_val = input$department)
      
      updateSelectInput(session, "fraction", choices = c("", fractions))
    })
    
    # --- 3. Return Filter Values ---
    active_filters <- eventReactive(input$run, {
      eq_filters <- list(); range_filters <- list()
      normalize <- function(x) { if (is.character(x) && !is.null(x) && x != "") stri_trans_general(x, "Latin-ASCII") else x }
      
      for (col in names(columns)) {
        if (!isTRUE(input[[paste0("chk_", col)]])) next
        col_type <- columns[[col]]
        
        if (col_type %in% c("text", "text_logic")) {
          val <- normalize(input[[paste0("val_", col)]])
          if (!is.null(val) && val != "") eq_filters[[col]] <- val
        } else if (col_type == "date_or_range") {
          mode <- input[[paste0("mode_", col)]]
          if (mode == "exact") {
            val <- normalize(input[[paste0("val_", col)]])
            if (!is.null(val) && val != "") eq_filters[[col]] <- as.Date(val)
          } else {
            rng <- input[[paste0("valrange_", col)]]
            if (!is.null(rng)) range_filters[[col]] <- as.Date(rng)
          }
        }
      }
      
      geo_cols <- c("country", "province", "department", "censal_fraction")
      for (col in geo_cols) {
        val <- normalize(input[[col]])
        if (!is.null(val) && val != "") eq_filters[[col]] <- val
      }
      
      list(
        eq_filters = eq_filters,
        range_filters = range_filters,
        age_range = input$age_range,
        country = input$country,
        province = input$province,
        department = input$department
      )
    })
    
    return(active_filters)
  })
}