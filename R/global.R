library(leaflet)
library(RSQLite)
library(shinyjs)
library(stringi)
library(readxl)
library(shiny)
library(dplyr)
library(here)
library(xml2)
library(DBI)
library(sf)

source("R/utils.R")

con <- dbConnect(SQLite(), here("data", "your_database.dba")) # using the same file that was used in the form example
table_name <- "reports"
reports_cols <- dbListFields(con, "reports")
raw_data <- reactiveVal(NULL)


gpkg_file <- here("data", "geometry.gpkg")
layers <- st_layers(gpkg_file)$name

gpkg_layers <- setNames(lapply(layers, function(layer) {
  st_read(gpkg_file, layer = layer)
}), layers)

###################################################
# To add filters add the name of the columns here #
###################################################
columns <- list(
  symptom_description  = "text_logic",
  symptom_onset_date   = "date_or_range",
  suspected_diagnosis  = "text",
  birth_date           = "age",
  location             = "geography"
)

# Column names are keys, display names are values
display_names <- c(
  suspected_diagnosis  = "Diagnosis",
  symptom_description  = "Symptoms",
  symptom_onset_date   = "Symptoms Onset Date",
  location             = "Location",
  country              = "Country",
  province             = "Province",
  department           = "Department",
  censal_fraction      = "Censal Fraction",
  birth_date           = "Age",
  sex                  = "Sex",
  Age                  = "Age",
  consultation_date    = "Consultation Date"
)

cols_for_table <- c(
  "suspected_diagnosis",
  "symptom_description",
  "symptom_onset_date",
  "country",
  "province",
  "department",
  "censal_fraction",
  "sex",
  "Age",
  "consultation_date"
)

# Where is the information being gathered from
population_layers <- list(
  Argentina = c("INDEC_2020")
  )
