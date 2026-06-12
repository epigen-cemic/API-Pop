# =============================================================================
# Shared configuration helpers
# =============================================================================

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

valid_country_names <- function(configs) {
  names(configs)[names(configs) != "(Select Country)"]
}

get_country_config <- function(configs, country) {
  if (is.null(country) || !nzchar(country) || is.null(configs[[country]])) {
    return(NULL)
  }
  configs[[country]]
}

get_mapping_keys <- function(country_cfg) {
  if (is.null(country_cfg) || is.null(country_cfg$mapping)) {
    return(character(0))
  }
  names(country_cfg$mapping)
}

get_mapping_config <- function(country_cfg, level_key) {
  if (is.null(country_cfg) || is.null(country_cfg$mapping[[level_key]])) {
    return(NULL)
  }
  country_cfg$mapping[[level_key]]
}

get_country_levels <- function(country_cfg, include_country = TRUE) {
  levels <- country_cfg$levels %||% character(0)
  if (include_country) {
    return(levels)
  }
  setdiff(levels, "country")
}

get_level_label <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  label <- level_cfg$ui_label %||% level_cfg$display_name %||% level_cfg$label %||% level_key
  tools::toTitleCase(gsub("_", " ", label))
}

get_level_db_column <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$db_column %||% level_cfg$csv_column %||% level_key
}

get_level_name_col <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$name_col %||% level_cfg$label_col %||% "nam"
}

get_level_spatial_id <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$spatial_id %||% level_cfg$db_column %||% level_key
}

get_finest_level_key <- function(country_cfg) {
  mapping_keys <- get_mapping_keys(country_cfg)
  if (length(mapping_keys) == 0) {
    return(NULL)
  }
  mapping_keys[[length(mapping_keys)]]
}

get_finest_mapping_config <- function(country_cfg) {
  finest <- get_finest_level_key(country_cfg)
  if (is.null(finest)) {
    return(NULL)
  }
  get_mapping_config(country_cfg, finest)
}
