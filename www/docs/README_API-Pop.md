# API-POP – Suspected Case Filtering and Population Output Tool

**Version:** `v2.0`

API-POP is an R/Shiny application for filtering suspected-case records and producing population-compatible outputs for epidemiological analysis. It is part of the PPT-UK Argentina Work Package toolset and is designed to work alongside CUSUM RAP, Geospatial RAP, and the Digital Dashboard.

## What is new in v2.0

- Multi-file upload review.
- Allowed/disallowed file status before appending records.
- Upload review table moved to a popup/modal.
- Local uploaded-data workflow that does not expose internal database details to users.
- Optional external database connection.
- Uploads can remain enabled even when an external database is configured.
- Config-driven geographic labels.
- `level3_norm` support for robust third-level filtering.
- Weekly summary export uses `n_cases`.
- Timestamped download filenames.
- Dashboard-aligned styling.
- Shared helper structure under `R/shared/`.

## Features

- Dynamic country and geographic level filters.
- Demographic filtering by available fields such as sex and age/date of birth.
- Symptom onset date filtering.
- Suspected diagnosis and symptom description filtering.
- Detailed filtered case export.
- Weekly case/population summary export.
- Configurable local or external data source.
- Support for existing upload formats, including CSV, Excel, XML, and local database files where enabled.

## Requirements

Recommended:

- R >= 4.2
- RStudio or another R IDE
- Packages used by the app may include:

```r
install.packages(c(
  "shiny",
  "shinyjs",
  "DT",
  "dplyr",
  "DBI",
  "RSQLite",
  "pool",
  "config",
  "yaml",
  "jsonlite",
  "readr",
  "readxl",
  "xml2",
  "here",
  "uuid"
))
```

External database deployments may require additional drivers or packages, such as `odbc`.

## Run locally

```r
setwd("path/to/API-Pop")
shiny::runApp()
```

Or from a terminal:

```bash
Rscript --vanilla -e "shiny::runApp('.', host = '127.0.0.1', port = 3838)"
```

## Data source modes

API-POP v2.0 supports:

| Mode | Description |
|---|---|
| Local uploaded data | Users upload files and valid records are appended to the local app data store. |
| External database | Administrators configure a database connection in `config.yaml`. |
| Mixed workflow | External database is configured, but uploads remain enabled for additional files. |

The internal local store should not be presented to end users as a database. In user-facing documentation, refer to it as local app data or uploaded data.

## Configuration

Main files:

| File | Purpose |
|---|---|
| `config.yaml` | Runtime profile, data source, database path/connection, and app data paths. |
| `config.json` | Country/geographic mappings and display labels. |
| `WWW/config.css` | Theme and visual styling. |
| `.Renviron` | Optional environment/profile variables and secrets. |

## Standard outputs

### Filtered case list

Detailed records matching the selected filters. See `Data_Dictionary_API-Pop_cases.md`.

### Weekly summary

Aggregated output for downstream RAP tools. See `Data_Dictionary_API-Pop_weekly_pop.md`.

The v2.0 weekly count field is:

```text
n_cases
```

## Data preparation scripts

| Script | Purpose |
|---|---|
| `data_prep/merge_layers.R` | Prepare country `.gpkg` files for geographic filtering. |
| `data_prep/connect_database_example.R` | Example for testing an external data source connection. |
| `data_prep/prepare_api_pop_database.R` | Prepare/reset the local app data store for testing. |

## Deployment notes

Before deployment:

- Confirm uploads work.
- Confirm filters load correctly.
- Confirm invalid files are disallowed without crashing.
- Confirm downloads use timestamped filenames.
- Confirm `n_cases` is present in the weekly summary.
- Confirm no credentials are committed.
- Confirm no test records are committed in local app data files.

## Contact

**Project:** PPT-UK – Argentina Work Package WS5
**Institution / Delivery Partner:** CEMIC
