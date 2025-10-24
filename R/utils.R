fix_encoding_to_utf8 <- function(con, table = "reports") {
  cols <- c("country", "province", "department")
  for (col in cols) {
    rows <- dbGetQuery(con, sprintf("SELECT rowid, %s FROM %s", col, table))
    rows[[col]] <- vapply(rows[[col]], function(x) {
      # Convert from Latin-1 → UTF-8 safely
      enc2utf8(iconv(x, from = "latin1", to = "UTF-8"))
    }, character(1))
    
    for (i in seq_len(nrow(rows))) {
      dbExecute(
        con,
        sprintf("UPDATE %s SET %s = ? WHERE rowid = ?", table, col),
        params = list(rows[[col]][i], rows$rowid[i])
      )
    }
  }
  message("Encoding fixed to UTF-8.")
}    # For database if new upload is broken

to_utf8 <- function(df) {
  char_cols <- names(df)[sapply(df, is.character)]
  for (colname in char_cols) {
    df[[colname]] <- iconv(df[[colname]], from = "latin1", to = "UTF-8", sub = "")
  }
  return(df)
}

fix_accents <- function(x) {
  if (!is.character(x)) return(x)
  for (bad in names(fix_map)) {
    x <- gsub(bad, fix_map[bad], x, fixed = TRUE)
  }
  x
}

normalize_geography_batch <- function(con, table = "reports", batch_size = 1000) {
  cols <- c("country", "province", "department")
  existing_fields <- dbListFields(con, table)
  
  # Ensure _norm columns exist and indexes
  for (col in cols) {
    norm_col <- paste0(col, "_norm")
    if (!(norm_col %in% existing_fields)) {
      dbExecute(con, sprintf("ALTER TABLE %s ADD COLUMN %s TEXT", table, norm_col))
    }
    dbExecute(con, sprintf("CREATE INDEX IF NOT EXISTS idx_%s_norm ON %s(%s)", col, table, norm_col))
  }
  
  message("Normalizing geography columns in batches...")
  
  for (col in cols) {
    norm_col <- paste0(col, "_norm")
    last_rowid <- 0
    
    repeat {
      rows <- dbGetQuery(
        con,
        sprintf(
          "SELECT rowid, %s FROM %s WHERE %s IS NULL AND rowid > %d ORDER BY rowid LIMIT %d",
          col, table, norm_col, last_rowid, batch_size
        )
      )
      if (nrow(rows) == 0) break
      
      # Normalize in R
      rows[[col]] <- stringi::stri_trans_general(rows[[col]], "Latin-ASCII")
      
      # Build SQL updates directly
      for (i in seq_len(nrow(rows))) {
        value <- gsub("'", "''", rows[[col]][i]) # escape single quotes
        sql <- sprintf("UPDATE %s SET %s = '%s' WHERE rowid = %d",
                       table, norm_col, value, rows$rowid[i])
        dbExecute(con, sql)
      }
      
      last_rowid <- max(rows$rowid)
    }
  }
  
  message("Geography normalization complete.")
}    # Normalize text for location specific values

get_info_about_country <- function(information, layer_type, country, type = NULL, name = NULL, gpkg_file = here("data", "geometry.gpkg")) {
  layer_name <- paste0(layer_type, "_", tolower(country))
  information <- enc2utf8(information)
  layer_name   <- enc2utf8(layer_name)
  if (!is.null(type)) type <- enc2utf8(type)
  if (!is.null(name)) name <- enc2utf8(name)
  
  if (!is.null(type) && !is.null(name)) {
    name_sql <- gsub("'", "''", name)
    sql <- sprintf(
      "SELECT %s FROM %s WHERE %s LIKE '%%%s%%' COLLATE NOCASE",
      information, layer_name, type, name_sql
    )
  } else {
    sql <- sprintf("SELECT %s FROM %s", information, layer_name)
  }
  
  result <- st_read(gpkg_file, query = sql, quiet = TRUE)
  result <- to_utf8(result)
  result <- st_drop_geometry(result)
  return(result)
}

add_filters_to_sql <- function(sql, con, eq_filters = list(), range_filters = list(), age_range = NULL) {
  conditions <- character()
  if (!is.null(age_range)) {
    range_filters$Age <- age_range
  }
  
  for (colname in names(eq_filters)) {
    val <- eq_filters[[colname]]
    
    # Use normalized column for geography
    if (colname %in% c("country", "province", "department")) {
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

build_eq <- function(con, colname, val) {
  if (inherits(val, "Date")) {
    sprintf("%s = %s",
            dbQuoteIdentifier(con, colname),
            dbQuoteString(con, as.character(val)))
  } else {
    sprintf("%s LIKE %s COLLATE NOCASE",
            dbQuoteIdentifier(con, colname),
            dbQuoteString(con, paste0("%", val, "%")))
  }
}         # Exact match

build_range <- function(con, colname, rng) {
  sprintf("%s BETWEEN %s AND %s",
          dbQuoteIdentifier(con, colname),
          dbQuoteString(con, as.character(rng[1])),
          dbQuoteString(con, as.character(rng[2])))
}      # Range filter

build_logic <- function(con, colname, val) {
  or_groups <- strsplit(val, "\\s+or\\s")[[1]]
  
  or_clauses <- lapply(or_groups, function(group) {
    and_terms <- trimws(strsplit(group, "\\s+and\\s+")[[1]])
    and_clauses <- sapply(and_terms, function(term) {
      sprintf("%s LIKE %s",
              dbQuoteIdentifier(con, colname),
              dbQuoteString(con, paste0("%", stringi::stri_trans_general(term, "Latin-ASCII"), "%")))
    })
    paste0("(", paste(and_clauses, collapse = " AND "), ")")
  })
  
  paste(or_clauses, collapse = " OR ")
}      # Special AND / OR parser



