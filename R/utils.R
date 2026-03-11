#' Fix Encoding to UTF-8 for specific columns
#'
#' Iterates through the country, province, and department columns of the specified table,
#' converts Latin-1 encoding to UTF-8, and updates the database rows in place.
#'
#' @param con A DBIConnection object to the SQLite database.
#' @param table Character string. The name of the table to update. Default is "reports".
#' @return Invisible NULL.
#' @export
fix_encoding_to_utf8 <- function(con, table = "reports") {
  cols <- c("country", "province", "department")
  for (col in cols) {
    # Fetch rowid to ensure we update the exact correct row
    rows <- DBI::dbGetQuery(con, sprintf("SELECT rowid, %s FROM %s", col, table))
    
    # Convert vector to UTF-8
    rows[[col]] <- vapply(rows[[col]], function(x) {
      enc2utf8(iconv(x, from = "latin1", to = "UTF-8"))
    }, character(1))
    
    # Update row by row (safest for in-place encoding fixes)
    for (i in seq_len(nrow(rows))) {
      DBI::dbExecute(
        con,
        sprintf("UPDATE %s SET %s = ? WHERE rowid = ?", table, col),
        params = list(rows[[col]][i], rows$rowid[i])
      )
    }
  }
  message("Encoding fixed to UTF-8.")
}

#' Convert Data Frame Character Columns to UTF-8
#'
#' Detects character columns in a data frame and forces their encoding from Latin-1 to UTF-8.
#'
#' @param df A data frame.
#' @return The data frame with character columns converted to UTF-8.
#' @export
to_utf8 <- function(df) {
  char_cols <- names(df)[sapply(df, is.character)]
  for (colname in char_cols) {
    # Vectorized iconv is faster and safer than loop
    df[[colname]] <- iconv(df[[colname]], from = "latin1", to = "UTF-8", sub = "")
  }
  return(df)
}

#' Fix Common Accent Encoding Issues
#'
#' Replaces common mojibake (garbled text) with correct Spanish accented characters
#' based on a predefined global map (`fix_map`).
#'
#' @param x A character vector.
#' @return A character vector with corrected accents.
#' @export
fix_accents <- function(x) {
  if (!is.character(x)) return(x)
  # fix_map must be defined in global.R
  if (!exists("fix_map")) return(x)
  
  for (bad in names(fix_map)) {
    x <- gsub(bad, fix_map[bad], x, fixed = TRUE)
  }
  x
}

#' Normalize Geography Columns (Generic)
#'
#' Populates generic normalization columns (`level1_norm`, `level2_norm`, `country_norm`) 
#' by removing accents, converting to lowercase, and trimming whitespace. 
#' This allows for case-insensitive and accent-insensitive SQL querying.
#'
#' @param con A DBIConnection object to the SQLite database.
#' @param table Character string. The table name. Default is "reports".
#' @param batch_size Integer. Number of rows to process per transaction. Default is 1000.
#' @return Invisible NULL.
#' @export
normalize_geography_batch <- function(con, table = "reports", batch_size = 1000) {
  
  # Helper to clean strings
  clean_str <- function(x) {
    if (all(is.na(x))) return(x)
    # Ensure UTF-8 before passing to stringi to avoid crashes
    x <- iconv(x, from = "latin1", to = "UTF-8", sub = "")
    x <- stringi::stri_trans_general(x, "Latin-ASCII") 
    x <- tolower(x)
    x <- trimws(x)
    return(x)
  }
  
  # 1. Check which columns exist in the DB
  fields <- DBI::dbListFields(con, table)
  
  # Define pairs: Source Column -> Target Norm Column
  pairs <- list()
  if ("level1" %in% fields)  pairs[["level1"]]  <- "level1_norm"
  if ("level2" %in% fields)  pairs[["level2"]]  <- "level2_norm"
  if ("country" %in% fields) pairs[["country"]] <- "country_norm"
  
  if (length(pairs) == 0) return()
  
  # 2. Identify rows that need update (where norm is NULL)
  where_clauses <- sapply(pairs, function(tgt) paste0(tgt, " IS NULL"))
  where_sql <- paste(where_clauses, collapse = " OR ")
  
  count_query <- sprintf("SELECT count(*) FROM %s WHERE %s", table, where_sql)
  total_rows <- tryCatch(DBI::dbGetQuery(con, count_query)[[1]], error = function(e) 0)
  
  if (total_rows == 0) {
    message("No rows need normalization.")
    return()
  }
  
  message(paste("Normalizing", total_rows, "rows..."))
  
  # 3. Process in batches
  processed <- 0
  while (processed < total_rows) {
    cols_to_select <- paste(c("rowid", names(pairs)), collapse = ", ")
    select_sql <- sprintf("SELECT %s FROM %s WHERE %s LIMIT %d", 
                          cols_to_select, table, where_sql, batch_size)
    
    batch <- DBI::dbGetQuery(con, select_sql)
    if (nrow(batch) == 0) break
    
    updates <- list()
    for (src in names(pairs)) {
      tgt <- pairs[[src]]
      norm_values <- clean_str(batch[[src]])
      updates[[tgt]] <- norm_values
    }
    
    # Write back to DB using a transaction
    DBI::dbBegin(con)
    tryCatch({
      set_clause <- paste(paste0(unlist(pairs), " = ?"), collapse = ", ")
      update_sql <- sprintf("UPDATE %s SET %s WHERE rowid = ?", table, set_clause)
      
      params <- unname(updates)
      params[[length(params) + 1]] <- batch$rowid
      
      DBI::dbExecute(con, update_sql, params = params)
      DBI::dbCommit(con)
    }, error = function(e) {
      DBI::dbRollback(con)
      stop("Error during normalization batch: ", e$message)
    })
    
    processed <- processed + nrow(batch)
    message(sprintf("Processed %d / %d", processed, total_rows))
  }
  message("Normalization complete.")
}

#' Add Filters to SQL Query
#' 
#' Dynamically appends WHERE clauses to a base SQL statement based on 
#' user-selected filters, handling normalization for geographic tiers.
#'
#' @param sql Character. The base SQL query (e.g., "SELECT * FROM reports").
#' @param con A DBIConnection object.
#' @param eq_filters List. Named list of equality/logic filters.
#' @param range_filters List. Named list of date/numerical range filters.
#' @param age_range Numeric vector. A length-2 vector for min/max age.
#' @return Character. The modified SQL query with WHERE clauses.
#' @export
add_filters_to_sql <- function(sql, con, eq_filters = list(), range_filters = list(), age_range = NULL) {
  
  conditions <- character()
  
  # 1. Handle Age Range (from slider)
  if (!is.null(age_range)) {
    range_filters$Age <- age_range
  }
  
  # 2. Process Equality and Logic Filters
  for (colname in names(eq_filters)) {
    val <- eq_filters[[colname]]
    
    # Check if the column is a geographic tier that needs normalization mapping
    if (colname %in% c("country", "level1", "level2", "level3")) {
      colname_norm <- paste0(colname, "_norm")
      # Strip accents and normalize value for the SQL search
      val_norm <- stringi::stri_trans_general(val, "Latin-ASCII")
      conditions <- c(conditions, build_eq(con, colname_norm, val_norm))
      
    } else if (colname == "symptom_description") {
      # Use specialized helper for 'and/or' logic strings
      conditions <- c(conditions, build_logic(con, colname, val))
      
    } else {
      # Standard equality filter
      conditions <- c(conditions, build_eq(con, colname, val))
    }
  }
  
  # 3. Process Range Filters (Dates and Age)
  for (colname in names(range_filters)) {
    val <- range_filters[[colname]]
    conditions <- c(conditions, build_range(con, colname, val))
  }
  
  # 4. Final SQL Assembly
  if (length(conditions) > 0) {
    sql <- paste(sql, "WHERE", paste(conditions, collapse = " AND "))
  }
  
  return(sql)
}


#' Build Equality SQL Clause (NA-Safe Version)
#' @param con DBIConnection.
#' @param colname Column name.
#' @param val Value to match.
#' @return SQL string.
build_eq <- function(con, colname, val) {
  # isTruthy safely handles NULL, NA, and ""
  if (!shiny::isTruthy(val)) return(NULL)
  
  sprintf("%s = %s", 
          DBI::dbQuoteIdentifier(con, colname),
          DBI::dbQuoteString(con, as.character(val)))
}

#' Build Range SQL Clause
#' @param con DBIConnection.
#' @param colname Column name.
#' @param rng Vector of length 2 (min, max).
#' @return SQL string.
#' @keywords internal
build_range <- function(con, colname, rng) {
  sprintf("%s BETWEEN %s AND %s", DBI::dbQuoteIdentifier(con, colname),
          DBI::dbQuoteString(con, as.character(rng[1])), DBI::dbQuoteString(con, as.character(rng[2])))
}

#' Build Text Logic SQL Clause (AND/OR)
#' @param con DBIConnection.
#' @param colname Column name.
#' @param val String containing logical operators (e.g., "fever and cough").
#' @return SQL string.
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



#' Fetch Geographic Options Based on ID Matching
#' 
#' @param gpkg_path Path to the .gpkg file.
#' @param country The country key (e.g., "Argentina").
#' @param level_key The level we want to FILL (e.g., "level1", "level2").
#' @param parent_key The level the user JUST CLICKED (e.g., "level1").
#' @param parent_val The ID CODE of the selected parent (e.g., "06" for a province).
fetch_options <- function(gpkg_path, country, level_key, parent_key = NULL, parent_val = NULL) {
  # 1. Validation
  if (!exists("ALL_CONFIGS") || is.null(country) || country == "") return(character(0))
  config <- ALL_CONFIGS[[country]]
  target_map <- config$mapping[[level_key]]
  if (is.null(target_map)) return(character(0))
  
  name_col <- if(!is.null(target_map$name_col)) target_map$name_col else "nam"
  id_col   <- if(!is.null(target_map$spatial_id)) target_map$spatial_id else "rowid"
  
  # 2. SQL Build (ID-BASED)
  if (is.null(parent_key) || is.null(parent_val) || parent_val == "") {
    sql <- sprintf("SELECT DISTINCT %s, %s FROM %s ORDER BY %s", 
                   name_col, id_col, target_map$layer_name, name_col)
  } else {
    parent_map <- config$mapping[[parent_key]]
    sql <- sprintf("
      SELECT DISTINCT c.%s, c.%s
      FROM %s c
      JOIN %s p ON CAST(c.%s AS TEXT) = CAST(p.%s AS TEXT)
      WHERE p.%s = '%s'
      ORDER BY c.%s", 
                   name_col, id_col, target_map$layer_name, parent_map$layer_name, 
                   target_map$parent_col, parent_map$spatial_id, 
                   parent_map$spatial_id, parent_val, name_col)
  }
  
  # 3. Execution & Dual-Value Return
  res <- tryCatch({
    data <- sf::st_read(gpkg_path, query = sql, quiet = TRUE)
    data <- to_utf8(data) 
    
    # RE-FIXED: Return names = "Belén", values = "06" (the ID)
    # This makes the dropdowns work perfectly again.
    choices <- setNames(as.character(data[[id_col]]), as.character(data[[name_col]]))
    choices
    
  }, error = function(e) {
    message("Fetch Error: ", e$message)
    return(character(0))
  })
  return(res)
}


#' Check Valid Encoding
#'
#' Checks if a string has valid encoding by attempting to capture its output.
#'
#' @param x Character string.
#' @return Boolean. TRUE if valid, FALSE otherwise.
#' @keywords internal
validEnc <- function(x) {
  tryCatch({
    utils::capture.output(cat(x, file = nullfile()))
    return(TRUE)
  }, error = function(e) FALSE, warning = function(w) FALSE)
}