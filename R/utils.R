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

#' Add Dynamic Filters to SQL Query
#'
#' Appends WHERE clauses to a SQL query based on user inputs. Handles equality, 
#' date ranges, and specialized text logic (AND/OR groups).
#'
#' @param sql Character string. The base SQL query.
#' @param con A DBIConnection object.
#' @param eq_filters List of equality filters (col = val).
#' @param range_filters List of range filters (col BETWEEN val1 AND val2).
#' @param age_range Numeric vector of length 2. Age min and max.
#' @return A character string containing the complete SQL query.
#' @export
add_filters_to_sql <- function(sql, con, eq_filters = list(), range_filters = list(), age_range = NULL) {
  conditions <- character()
  if (!is.null(age_range)) range_filters$Age <- age_range
  
  for (colname in names(eq_filters)) {
    val <- eq_filters[[colname]]
    # Use generic normalized columns if available
    if (colname %in% c("country", "level1", "level2")) {
      colname_norm <- paste0(colname, "_norm")
      val <- stringi::stri_trans_general(val, "Latin-ASCII")
      conditions <- c(conditions, build_eq(con, colname_norm, val))
    } else if (colname == "symptom_description") {
      conditions <- c(conditions, build_logic(con, colname, val))
    } else {
      conditions <- c(conditions, build_eq(con, colname, val))
    }
  }
  
  for (colname in names(range_filters)) {
    conditions <- c(conditions, build_range(con, colname, range_filters[[colname]]))
  }
  
  if (length(conditions) > 0) {
    sql <- paste(sql, "WHERE", paste(conditions, collapse = " AND "))
  }
  sql
}

#' Build Equality SQL Clause
#' @param con DBIConnection.
#' @param colname Column name.
#' @param val Value to match.
#' @return SQL string.
#' @keywords internal
build_eq <- function(con, colname, val) {
  if (inherits(val, "Date")) {
    sprintf("%s = %s", DBI::dbQuoteIdentifier(con, colname), DBI::dbQuoteString(con, as.character(val)))
  } else {
    sprintf("%s LIKE %s COLLATE NOCASE", DBI::dbQuoteIdentifier(con, colname), DBI::dbQuoteString(con, paste0("%", val, "%")))
  }
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

#' Fetch Unique Options with In-Memory Parent Matching
#'
#' Retrieves unique values from the GeoPackage for a specific administrative level.
#' Uses a "Safe Parent Matching" strategy where parent names are fetched to R memory
#' to handle character encoding (accents) reliably without crashing SQLite.
#'
#' @param gpkg_path Character string. Path to the geometry .gpkg file.
#' @param country Character string. The selected country key.
#' @param level_name Character string. The config level name (e.g., "department").
#' @param parent_name Character string. The config level name of the parent (e.g., "province").
#' @param parent_val Character string. The value of the selected parent.
#' @return Character vector of unique options (cleaned to UTF-8).
#' @export
fetch_options <- function(gpkg_path, country, level_name, parent_name = NULL, parent_val = NULL) {
  
  # 1. Config Check
  if (!exists("ALL_CONFIGS")) {
    try(ALL_CONFIGS <<- jsonlite::fromJSON(here::here("www/config.json")), silent=TRUE)
  }
  
  if (is.null(country) || country == "" || country == "(Select Country)") return(character(0))
  if (is.null(level_name)) return(character(0))
  
  config <- ALL_CONFIGS[[country]]
  if (is.null(config)) return(character(0))
  
  target_map <- config$mapping[[level_name]]
  if (is.null(target_map)) return(character(0))
  
  target_layer <- target_map$spatial_layer
  if (is.null(target_layer)) target_layer <- target_map$source
  if (is.null(target_layer)) return(character(0))
  
  if (!file.exists(gpkg_path)) return(character(0))
  
  # Safeguard: Stop if parent is required but empty
  if (!is.null(parent_name)) {
    if (is.null(parent_val) || parent_val == "") return(character(0))
  }
  
  con_geo <- RSQLite::dbConnect(RSQLite::SQLite(), gpkg_path)
  on.exit(RSQLite::dbDisconnect(con_geo))
  
  # Helper: Clean Encoding
  clean_vec <- function(x) {
    # If we accidentally get binary data, convert to string safely or warn
    if(is.raw(x) || is.list(x)) return(as.character(x)) 
    x <- iconv(x, from = "latin1", to = "UTF-8", sub = "")
    return(x)
  }
  
  # 2. Detect Name Column (THE FIX)
  fields <- tryCatch(RSQLite::dbListFields(con_geo, target_layer), error = function(e) NULL)
  if (is.null(fields)) return(character(0))
  
  # Priority 1: Configured 'name_col'
  if (!is.null(target_map$name_col) && target_map$name_col %in% fields) {
    target_col <- target_map$name_col
    
    # Priority 2: Standard Names
  } else if ("nam" %in% fields) {
    target_col <- "nam"
  } else if ("name" %in% fields) {
    target_col <- "name"
  } else if ("nombre" %in% fields) {
    target_col <- "nombre"
    
    # Priority 3: SPATIAL ID (Fix for Fractions)
    # If no name exists, use the ID (e.g., cod_indec) as the display label
  } else {
    spatial_id <- if(!is.null(target_map$spatial_id)) target_map$spatial_id else target_map$id_col
    if (!is.null(spatial_id) && spatial_id %in% fields) {
      target_col <- spatial_id
    } else {
      # Fallback (risky, but better than crash)
      target_col <- fields[1] 
    }
  }
  
  # 3. Build Query
  if (!is.null(parent_name) && !is.null(parent_val) && parent_val != "") {
    
    # --- PARENT MATCHING ---
    parent_map <- config$mapping[[parent_name]]
    if(is.null(parent_map)) return(character(0))
    
    parent_layer    <- if(!is.null(parent_map$spatial_layer)) parent_map$spatial_layer else parent_map$source
    parent_link_col <- if(!is.null(parent_map$spatial_id)) parent_map$spatial_id else parent_map$id_col
    
    p_fields <- RSQLite::dbListFields(con_geo, parent_layer)
    
    # Determine Parent Name Column
    p_name_col <- "nam"
    if (!is.null(parent_map$name_col) && parent_map$name_col %in% p_fields) {
      p_name_col <- parent_map$name_col
    } else if ("name" %in% p_fields) { p_name_col <- "name" }
    else if ("nombre" %in% p_fields) { p_name_col <- "nombre" }
    
    # Fetch Parents
    q_parents <- sprintf("SELECT %s, %s FROM %s", parent_link_col, p_name_col, parent_layer)
    df_parents <- RSQLite::dbGetQuery(con_geo, q_parents)
    
    if (nrow(df_parents) == 0) return(character(0))
    
    # Match Name in R
    db_names_clean <- clean_vec(as.vector(df_parents[[p_name_col]]))
    match_idx <- which(db_names_clean == parent_val)
    if (length(match_idx) == 0) match_idx <- which(tolower(db_names_clean) == tolower(parent_val))
    if (length(match_idx) == 0) match_idx <- which(trimws(db_names_clean) == trimws(parent_val))
    
    if (length(match_idx) == 0) return(character(0))
    
    # Get ID
    raw_id <- df_parents[[parent_link_col]][match_idx[1]]
    
    child_ref_col <- target_map$parent_col 
    
    # Robust Query (Handles Text vs Int ID mismatch)
    query <- sprintf("SELECT DISTINCT %s FROM %s WHERE CAST(%s AS TEXT) = '%s' OR CAST(%s AS INT) = %s ORDER BY 1", 
                     target_col, target_layer, 
                     child_ref_col, as.character(raw_id),
                     child_ref_col, suppressWarnings(as.numeric(raw_id)))
    
  } else {
    # --- TOP LEVEL QUERY ---
    query <- sprintf("SELECT DISTINCT %s FROM %s ORDER BY 1", 
                     target_col, target_layer)
  }
  
  # 4. Execute
  tryCatch({
    res <- RSQLite::dbGetQuery(con_geo, query)
    if(nrow(res) == 0) return(character(0))
    
    raw_vec <- as.vector(res[[1]])
    
    if (is.raw(raw_vec) || is.list(raw_vec)) {
      # Should not happen now, but as a final safety:
      return(as.character(raw_vec))
    }
    
    raw_vec <- raw_vec[!is.na(raw_vec)]
    return(clean_vec(raw_vec))
    
  }, error = function(e) {
    return(character(0))
  })
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