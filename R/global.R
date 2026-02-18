# ==============================================================================
# 1. LOAD LIBRARIES
# ==============================================================================
library(shiny)
library(shinyjs)
library(jsonlite)
library(sf)
library(DT)
library(RSQLite)
library(DBI)
library(stringi)
library(readxl)
library(dplyr)
library(here)
library(xml2)

# Load helper functions first
source("R/utils.R")
source("R/main_analysis.R") 
source("R/modules/filters.R")
source("R/modules/results.R")
source("R/modules/upload.R")

config_path <- here::here("www/config.json")
if (file.exists(config_path)) {
  ALL_CONFIGS <- jsonlite::fromJSON(config_path)
} else {
  stop("config.json not found in www/ folder!")
}

# Database Connection
con <- RSQLite::dbConnect(RSQLite::SQLite(), here::here("data", "your_database.dba"))

table_name <- "reports"
reports_cols <- RSQLite::dbListFields(con, table_name)
raw_data <- shiny::reactiveVal(NULL)

# --- GEOMETRY PATH DEFINITION ---
gpkg_path <- here::here("data", "geometry.gpkg")

# App Constants
columns <- list(
  symptom_description = "text_logic",
  symptom_onset_date  = "date_or_range",
  suspected_diagnosis = "text",
  birth_date          = "age",
  location            = "geography"
)

display_names <- c(
  suspected_diagnosis = "Diagnosis",
  symptom_description = "Symptoms",
  symptom_onset_date  = "Symptoms Onset Date",
  location            = "Location",
  country             = "Country",
  province            = "Province",
  department          = "Department",
  fraction     = "Censal Fraction",
  birth_date          = "Age",
  sex                 = "Sex",
  Age                 = "Age",
  consultation_date   = "Consultation Date"
)

cols_for_table <- c(
  "suspected_diagnosis",
  "symptom_description",
  "symptom_onset_date",
  "country",
  "province",
  "department",
  "fraction",
  "sex",
  "Age",
  "consultation_date"
)

fix_map <- c(
  "Ã¡" = "á", "Ã©" = "é", "Ã­" = "í", "Ã³" = "ó", "Ãº" = "ú",
  "Ã " = "Á", "Ã‰" = "É", "Ã " = "Í", "Ã“" = "Ó", "Ãš" = "Ú",
  "Ã±" = "ñ", "Ã‘" = "Ñ", "Ã¼" = "ü", "Ãœ" = "Ü"
)

population_layers <- list(
  Argentina = c("INDEC_2020")
)