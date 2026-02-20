resultsUI <- function(id) {
  ns <- NS(id)
  tagList(
    # Download buttons
    div(class = "btn-container",
        downloadButton(ns("download_csv"), "Cases List", class = "btn-block"),
        downloadButton(ns("download_summary_csv"), "Weekly Summary", class = "btn-block")
    ),
    # Results Table
    tableOutput(ns("results"))
  )
}

resultsServer <- function(id, data_reactive, cols_for_table, display_names, filter_metadata) {
  moduleServer(id, function(input, output, session) {
    
    # 1. Render Table
    output$results <- renderTable({
      req(data_reactive())
      df <- data_reactive()[, cols_for_table, drop = FALSE]
      geo_cols <- intersect(c("country", "province", "department"), names(df))
      if (length(geo_cols) > 0) df[geo_cols] <- lapply(df[geo_cols], fix_accents)
      colnames(df) <- display_names[cols_for_table]
      df
    }, sanitize.text.function = function(x) x)
    
    # 2. Download Cases
    output$download_csv <- downloadHandler(
      filename = function() { paste0("query_results_", Sys.Date(), ".csv") },
      content = function(file) {
        req(data_reactive())
        write.csv(data_reactive(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
    
    output$download_summary_csv <- downloadHandler(
      filename = function() { paste0("weekly_summary_", Sys.Date(), ".csv") },
      content = function(file) {
        df <- data_reactive()
        req(df)
        
        # A. Get Metadata from the filters
        meta <- filter_metadata() # Contains country, province, department selections
        req(meta$country)
        
        # B. Read Config for the lowest level (Fraction)
        config <- ALL_CONFIGS[[meta$country]]
        fraction_config <- config$mapping[["fraction"]]
        
        # Extract Spatial settings from config (with defaults)
        layer_name <- if(!is.null(fraction_config$spatial_layer)) fraction_config$spatial_layer else "fracc_argentina"
        id_col     <- if(!is.null(fraction_config$spatial_id))    fraction_config$spatial_id    else "cod_indec"
        
        # C. Summarize Data
        df <- df %>% 
          mutate(
            year = strftime(as.Date(consultation_date), format = "%Y"),
            week = strftime(as.Date(consultation_date), format = "%U")
          )
        summary_df <- df %>% 
          group_by(year, week, censal_fraction) %>% 
          summarise(n_cases = n(), .groups = "drop")
        
        # D. Load Spatial Data (Population)
        gpkg_file <- here::here("data", "geometry.gpkg")
        
        # We assume the user wants to join the 'fraction' level to the spatial file
        pop_df <- sf::st_read(gpkg_file, layer = layer_name, quiet = TRUE) %>%
          sf::st_drop_geometry() 
        
        # E. Dynamic Rename for Join
        # Rename the configured ID column (e.g. 'cod_indec') to 'join_id'
        if(id_col %in% names(pop_df)) {
          names(pop_df)[names(pop_df) == id_col] <- "join_id"
        }
        
        # Ensure Population column exists
        if(!"Population" %in% names(pop_df) && "total_population" %in% names(pop_df)) {
          # standardized naming
        } else if ("Population" %in% names(pop_df)) {
          names(pop_df)[names(pop_df) == "Population"] <- "total_population"
        }
        
        # Standardize IDs (Remove leading zeros issues)
        summary_df$join_id <- as.character(as.numeric(summary_df$censal_fraction))
        pop_df$join_id     <- as.character(as.numeric(pop_df$join_id))
        
        # F. Perform Join
        summary_df <- summary_df %>% left_join(pop_df, by = "join_id")
        
        # Fill missing population
        if(!"total_population" %in% colnames(summary_df)) summary_df$total_population <- NA
        
        # Add Location Context
        summary_df <- summary_df %>% 
          mutate(
            country = meta$country, 
            level1 = meta$province,
            level2 = meta$department
          ) %>%
          # rename(new_name = old_name) within select()
          select(
            country, 
            level1, 
            level2, 
            level3 = censal_fraction,
            year, 
            week, 
            n_cases, 
            total_population
          )
        
        # Write the file
        write.csv(summary_df, file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}