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

add_filters_to_sql <- function
(sql, con, eq_filters = list(), range_filters = list(), age_range = NULL) {
  conditions <- character()
  if (!is.null(age_range)) {
    range_filters$Age <- age_range
  }
  
  for (colname in names(eq_filters)) {
    val <- eq_filters[[colname]]
    if (colname == "symptom_description") {
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
    sprintf("%s LIKE %s",
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
  val <- tolower(val)
  or_groups <- strsplit(val, "\\s+or\\s")[[1]]
  or_clauses <- lapply(or_groups, function(group) {
    and_terms <- trimws(strsplit(group, "\\s+and\\s+")[[1]])
    and_clauses <- paste0(
      dbQuoteIdentifier(con, colname), " LIKE ",
      sapply(and_terms, function(term)
        dbQuoteString(con, paste0("%", term, "%"))),
      " COLLATE NOCASE")
    paste0("(", paste(and_clauses, collapse = " AND "), ")")})
  paste(or_clauses, collapse = " OR ")
}      # Special AND / OR parser

to_utf8 <- function(df) {
  char_cols <- names(df)[sapply(df, is.character)]
  for (colname in char_cols) {
    df[[colname]] <- iconv(df[[colname]], from = "latin1", to = "UTF-8", sub = "")
  }
  return(df)
}
