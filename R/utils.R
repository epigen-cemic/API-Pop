#' Convert character data to UTF-8
#'
#' Convert a character vector or character columns in a data frame using iconv; other inputs are
#' returned unchanged.
#'
#' @param x Input value or object to process.
#' @return The converted object, preserving its basic structure.
#' @export
to_utf8 <- function(x) {
  if (is.data.frame(x)) {
    x[] <- lapply(x, function(col) {
      if (is.character(col)) {
        return(iconv(col, from = "", to = "UTF-8"))
      }
      return(col)
    })
    return(x)
  } else if (is.character(x)) {
    return(iconv(x, from = "", to = "UTF-8"))
  }
  return(x)
}

#' Read CSV using estimated encoding
#'
#' Estimate text encoding from a byte sample using stringi and read the CSV as character columns.
#' Encoding detection is heuristic.
#'
#' @details Encoding is estimated rather than guaranteed. Numeric-looking CSV fields are
#'   intentionally read as character data at this stage.
#'
#' @param filepath Path to an uploaded data file.
#' @return A data frame with character columns.
#' @keywords internal
read_csv_safely <- function(filepath) {
  raw_bytes <- readBin(filepath, what = "raw", n = 10000)
  detected <- stringi::stri_enc_detect(raw_bytes)
  best_guess <- detected[[1]]$Encoding[1]
  
  if (is.na(best_guess) || best_guess == "ASCII") {
    best_guess <- "UTF-8"
  }
  
  # Normalize common Latin encodings
  if (grepl("windows|iso-8859|latin", tolower(best_guess))) {
    best_guess <- "latin1"
  }
  
  df <- utils::read.csv(
    filepath,
    stringsAsFactors = FALSE,
    fileEncoding = best_guess,
    colClasses = "character"
  )
  
  return(df)
}

#' Read an uploaded data file
#'
#' Dispatch CSV, XLSX, XML, or DBA input to the corresponding parser, then normalize character
#' encoding.
#'
#' @param filepath Path to an uploaded data file.
#' @param ext Filename extension without the leading dot.
#' @param target_table Name of the destination table, including for uploaded SQLite databases.
#' @return A data frame parsed from the uploaded file.
#' @keywords internal
read_uploaded_file <- function(filepath, ext, target_table) {
  df <- switch(ext,
               "csv"  = read_csv_safely(filepath),
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
                 d <- DBI::dbReadTable(con2, target_table)
                 DBI::dbDisconnect(con2)
                 d
               },
               stop("Unsupported file type")
  )
  
  # Normalize character columns after parsing each supported format.
  df[] <- lapply(df, fix_encoding)
  
  return(df)
}

#' Normalize text for matching
#'
#' Convert valid text to UTF-8, transliterate Latin accents, trim whitespace, and lowercase values.
#'
#' @param x Input value or object to process.
#' @return A normalized character vector; returns NA for NULL or empty input.
#' @keywords internal
normalize <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA)
  v <- as.character(x)
  valid <- !is.na(v) & v != ""
  
  v[valid] <- iconv(v[valid], from = "", to = "UTF-8")
  v[valid] <- stringi::stri_trans_general(v[valid], "Latin-ASCII")
  
  return(tolower(trimws(v)))
}

#' Append case-filter conditions to SQL
#'
#' Construct WHERE conditions for selected geographic, text, range, and age filters using DBI
#' quoting helpers.
#'
#' @details The current builder combines clauses with AND but does not group the OR expression
#'   produced by build_logic. Review SQL precedence before modifying or relying on mixed symptom
#'   filters.
#'
#' @param sql Base SQL SELECT statement.
#' @param con A DBI database connection or compatible pool.
#' @param eq_filters Named list of equality or text-filter values.
#' @param range_filters Named list of two-element range boundaries.
#' @param age_range Optional minimum and maximum age filter values.
#' @return An SQL query string containing the appended conditions.
#' @export
add_filters_to_sql <- function(sql, con, eq_filters = list(), range_filters = list(), age_range = NULL) {
  
  conditions <- character()
  
  # Treat age limits as another database range condition.
  if (!is.null(age_range)) {
    range_filters$Age <- age_range
  }
  
  # Geographic comparisons use normalized companion columns.
  for (colname in names(eq_filters)) {
    val <- eq_filters[[colname]]
    
    # Check if the column is a geographic tier that needs normalization mapping
    if (colname %in% c("country", "level1", "level2", "level3")) {
      colname_norm <- paste0(colname, "_norm")
      # Strip accents and normalize value for the SQL search
      val_norm <- normalize(val)
      conditions <- c(conditions, build_eq(con, colname_norm, val_norm))
      
    } else if (colname == "symptom_description") {
      # Use specialized helper for 'and/or' logic strings
      conditions <- c(conditions, build_logic(con, colname, val))
      
    } else {
      # Standard equality filter
      conditions <- c(conditions, build_eq(con, colname, val))
    }
  }
  
  # Date and age ranges are handled separately from equality filters.
  for (colname in names(range_filters)) {
    val <- range_filters[[colname]]
    conditions <- c(conditions, build_range(con, colname, val))
  }
  
  # Combine all active filter conditions into a single WHERE clause.
  if (length(conditions) > 0) {
    sql <- paste(sql, "WHERE", paste(conditions, collapse = " AND "))
  }
  
  return(sql)
}


#' Build a quoted equality condition
#'
#' Generate a field = value expression with DBI identifier and literal quoting when the selection
#' is meaningful.
#'
#' @param con A DBI database connection or compatible pool.
#' @param colname Database column name to filter.
#' @param val Selected value or text condition.
#' @return An SQL condition string or NULL for an empty selection.
#' @keywords internal
build_eq <- function(con, colname, val) {
  # An unset selection must not add a SQL equality condition.
  if (!shiny::isTruthy(val)) return(NULL)
  
  sprintf("%s = %s", 
          DBI::dbQuoteIdentifier(con, colname),
          DBI::dbQuoteString(con, as.character(val)))
}

#' Build a quoted range condition
#'
#' Generate a BETWEEN expression from the first and second bounds.
#'
#' @param con A DBI database connection or compatible pool.
#' @param colname Database column name to filter.
#' @param rng Two-element lower and upper range boundaries.
#' @return An SQL condition string.
#' @keywords internal
build_range <- function(con, colname, rng) {
  sprintf("%s BETWEEN %s AND %s", DBI::dbQuoteIdentifier(con, colname),
          DBI::dbQuoteString(con, as.character(rng[1])), DBI::dbQuoteString(con, as.character(rng[2])))
}

#' Build symptom-text AND/OR conditions
#'
#' Parse textual and/or terms and generate LIKE clauses for symptom descriptions. The returned OR
#' expression is not wrapped as a single group.
#'
#' @param con A DBI database connection or compatible pool.
#' @param colname Database column name to filter.
#' @param val Selected value or text condition.
#' @return An SQL condition string.
#' @keywords internal
build_logic <- function(con, colname, val) {
  or_groups <- strsplit(val, "\\s+or\\s")[[1]]
  or_clauses <- lapply(or_groups, function(group) {
    and_terms <- trimws(strsplit(group, "\\s+and\\s+")[[1]])
    and_clauses <- sapply(and_terms, function(term) {
      sprintf("%s LIKE %s", DBI::dbQuoteIdentifier(con, colname),
              DBI::dbQuoteString(con, paste0("%", stringi::stri_trans_general(term, "Latin-ASCII"), "%")))
    })
    paste0("(", paste(and_clauses, collapse = " AND "), ")")
  })
  paste(or_clauses, collapse = " OR ")
}



#' Read geographic choices from the GeoPackage
#'
#' Query configured spatial layers to obtain named geographic ID choices, optionally restricting
#' them to a selected parent.
#'
#' @details The query relies on the configured spatial layer and parent identifiers. A failed read
#'   is logged and exposed to callers as no choices.
#'
#' @param gpkg_path Path to the country GeoPackage containing configured geographic layers.
#' @param country Configured country key.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @param parent_key Generic key of the parent geographic level, if selected.
#' @param parent_val Identifier of the selected parent area, if any.
#' @return A named character vector of IDs or an empty vector on failure.
#' @keywords internal
fetch_options <- function(gpkg_path, country, level_key, parent_key = NULL, parent_val = NULL) {
  # An invalid selection must not trigger a spatial query.
  if (!exists("ALL_CONFIGS") || is.null(country) || country == "") return(character(0))
  
  config <- ALL_CONFIGS[[country]]
  target_map <- config$mapping[[level_key]]
  if (is.null(target_map)) return(character(0))
  
  name_col <- if (!is.null(target_map$name_col)) target_map$name_col else "nam"
  id_col   <- if (!is.null(target_map$spatial_id)) target_map$spatial_id else "rowid"
  
  # Match child layers to the configured parent spatial identifiers.
  if (is.null(parent_key) || is.null(parent_val) || parent_val == "") {
    
    sql <- sprintf(
      "SELECT DISTINCT %s, %s FROM %s ORDER BY %s",
      name_col, id_col, target_map$layer_name, name_col
    )
    
  } else {
    
    parent_map <- config$mapping[[parent_key]]
    
    sql <- sprintf(
      "SELECT DISTINCT c.%s, c.%s
       FROM %s c
       JOIN %s p ON CAST(c.%s AS TEXT) = CAST(p.%s AS TEXT)
       WHERE p.%s = '%s'
       ORDER BY c.%s",
      name_col, id_col,
      target_map$layer_name, parent_map$layer_name,
      target_map$parent_col, parent_map$spatial_id,
      parent_map$spatial_id, parent_val,
      name_col
    )
  }
  
  # Return identifier-valued choices for the dependent geographic selector.
  res <- tryCatch({
    
    data <- sf::st_read(gpkg_path, query = sql, quiet = TRUE)
    
    # Named vector: names = labels (UI), values = IDs (server logic)
    choices <- setNames(
      as.character(data[[id_col]]),
      as.character(data[[name_col]])
    )
    
    choices
    
  }, error = function(e) {
    message("Fetch Error: ", e$message)
    return(character(0))
  })
  
  return(res)
}


#' Repair invalid UTF-8 strings
#'
#' Keep valid UTF-8 unchanged and attempt Latin-1 conversion for invalid character entries.
#'
#' @param x Input value or object to process.
#' @return The input vector with recoverable invalid encodings converted.
#' @keywords internal
fix_encoding <- function(x) {
  if (!is.character(x)) return(x)
  
  # Preserve already valid UTF-8 entries.
  valid_utf8 <- !is.na(iconv(x, from = "UTF-8", to = "UTF-8"))
  
  # Attempt Latin-1 conversion only for values that are not valid UTF-8.
  x[!valid_utf8] <- iconv(x[!valid_utf8], from = "latin1", to = "UTF-8", sub = "")
  
  return(x)
}


#' Pad configured geographic codes
#'
#' Left-pad codes to their country-specific configured lengths for rows belonging to each
#' configured country.
#'
#' @param df Data frame containing input or output records.
#' @param config_list Named list of country geographic configurations.
#' @return The input data frame with applicable geographic values padded.
#' @keywords internal
apply_code_length_rules <- function(df, config_list) {
  
  if (!"country" %in% names(df)) return(df)
  
  for (country_name in names(config_list)) {
    
    country_cfg <- config_list[[country_name]]
    mapping <- country_cfg$mapping
    
    if (is.null(mapping)) next
    
    # Apply each country-specific rule only to matching records.
    idx <- which(df$country == country_name)
    if (length(idx) == 0) next
    
    for (level_name in names(mapping)) {
      
      level_cfg <- mapping[[level_name]]
      
      # Leave levels without configured widths unchanged.
      if (is.null(level_cfg$code_length)) next
      
      col <- level_cfg$db_column
      width <- level_cfg$code_length
      
      if (!col %in% names(df)) next
      
      # Pad only rows associated with this country.
      df[[col]][idx] <- ifelse(
        nchar(df[[col]][idx]) < width,
        stringr::str_pad(df[[col]][idx], width, side = "left", pad = "0"),
        df[[col]][idx]
      )
    }
  }
  
  return(df)
}