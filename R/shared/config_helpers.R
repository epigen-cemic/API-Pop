# =============================================================================
# Shared configuration helpers
# =============================================================================

#' Use a fallback for missing configuration
#'
#' Return the second argument when the first argument is NULL or empty.
#'
#' @param x Input value or object to process.
#' @param y Fallback value when x is missing.
#' @return The first nonempty value or the fallback.
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

#' List configured selectable countries
#'
#' Return country configuration names excluding the artificial selector entry.
#'
#' @param configs Named collection of country configurations.
#' @return A character vector of configured country names.
#' @keywords internal
valid_country_names <- function(configs) {
  names(configs)[names(configs) != "(Select Country)"]
}

#' Get a selected country configuration
#'
#' Return the named country configuration when it exists and the selection is nonempty.
#'
#' @param configs Named collection of country configurations.
#' @param country Configured country key.
#' @return A configuration list or NULL.
#' @keywords internal
get_country_config <- function(configs, country) {
  if (is.null(country) || !nzchar(country) || is.null(configs[[country]])) {
    return(NULL)
  }
  configs[[country]]
}

#' List geographic mapping keys
#'
#' Return the configured keys for geographic levels.
#'
#' @param country_cfg Parsed settings for one country.
#' @return A character vector of geographic level keys.
#' @keywords internal
get_mapping_keys <- function(country_cfg) {
  if (is.null(country_cfg) || is.null(country_cfg$mapping)) {
    return(character(0))
  }
  names(country_cfg$mapping)
}

#' Get geographic level configuration
#'
#' Retrieve the mapping for a generic geographic level.
#'
#' @param country_cfg Parsed settings for one country.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @return A mapping list or NULL.
#' @keywords internal
get_mapping_config <- function(country_cfg, level_key) {
  if (is.null(country_cfg) || is.null(country_cfg$mapping[[level_key]])) {
    return(NULL)
  }
  country_cfg$mapping[[level_key]]
}

#' List country geographic levels
#'
#' Return configured levels, optionally excluding the country selection itself.
#'
#' @param country_cfg Parsed settings for one country.
#' @param include_country Whether to retain the country level in the returned level names.
#' @return A character vector of geographic levels.
#' @keywords internal
get_country_levels <- function(country_cfg, include_country = TRUE) {
  levels <- country_cfg$levels %||% character(0)
  if (include_country) {
    return(levels)
  }
  setdiff(levels, "country")
}

#' Resolve a geographic UI label
#'
#' Choose the configured UI label, display name, or fallback level key and format it for display.
#'
#' @param country_cfg Parsed settings for one country.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @return A human-readable character label.
#' @keywords internal
get_level_label <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  label <- level_cfg$ui_label %||% level_cfg$display_name %||% level_cfg$label %||% level_key
  tools::toTitleCase(gsub("_", " ", label))
}

#' Resolve a geographic database column
#'
#' Return the configured database or CSV field name for a level.
#'
#' @param country_cfg Parsed settings for one country.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @return A character column name.
#' @keywords internal
get_level_db_column <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$db_column %||% level_cfg$csv_column %||% level_key
}

#' Resolve the geographic display-name field
#'
#' Return the configured name/label column in a spatial layer.
#'
#' @param country_cfg Parsed settings for one country.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @return A character column name.
#' @keywords internal
get_level_name_col <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$name_col %||% level_cfg$label_col %||% "nam"
}

#' Resolve the geographic identifier field
#'
#' Return the configured spatial identifier or its fallback field.
#'
#' @param country_cfg Parsed settings for one country.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @return A character column name.
#' @keywords internal
get_level_spatial_id <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$spatial_id %||% level_cfg$db_column %||% level_key
}

#' Identify the finest configured geographic level
#'
#' Return the last geographic mapping key when at least one is configured.
#'
#' @param country_cfg Parsed settings for one country.
#' @return A character level key or NULL.
#' @keywords internal
get_finest_level_key <- function(country_cfg) {
  mapping_keys <- get_mapping_keys(country_cfg)
  if (length(mapping_keys) == 0) {
    return(NULL)
  }
  mapping_keys[[length(mapping_keys)]]
}

#' Get the finest geographic mapping
#'
#' Resolve the mapping of the last configured geographic level.
#'
#' @param country_cfg Parsed settings for one country.
#' @return A mapping list or NULL.
#' @keywords internal
get_finest_mapping_config <- function(country_cfg) {
  finest <- get_finest_level_key(country_cfg)
  if (is.null(finest)) {
    return(NULL)
  }
  get_mapping_config(country_cfg, finest)
}
