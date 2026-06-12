# API-POP v2.0

API-POP is a Shiny-based suspected-case filtering and population-output tool developed for the PPT-UK Argentina Work Package toolset.

It helps users review case records, filter by geography and demographics, and export data in formats compatible with CUSUM RAP, Geospatial RAP, and the Digital Dashboard.

## Highlights

- Multi-file upload workflow.
- Allowed/disallowed file review.
- Upload review modal.
- Local uploaded-data workflow.
- Optional external database connection.
- Uploads can remain enabled when an external database is configured.
- Config-driven geography labels.
- Robust normalized filters including `level3_norm`.
- Filtered case export.
- Weekly `n_cases` + population export.
- Timestamped download filenames.
- Dashboard-aligned theme.

## Quick start

```r
setwd("path/to/API-Pop")
shiny::runApp()
```

## Install packages

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

External database deployments may require additional packages or drivers, such as `odbc`.

## Main outputs

| Output | Description |
|---|---|
| Filtered case list | Detailed records matching the selected filters. |
| Weekly summary | Aggregated `year`, `week`, geography, `n_cases`, and `population`. |

## Configuration files

| File | Purpose |
|---|---|
| `config.yaml` | Runtime profile, local/external data source, database connection/path. |
| `config.json` | Country, geographic levels, spatial mappings, and display names. |
| `WWW/config.css` | Visual theme and layout styling. |
| `.Renviron` | Local environment variables and secrets. Do not commit. |

## Data source modes

API-POP v2.0 supports local uploaded data, external database mode, and mixed mode where both are available.

The internal local data store should be hidden from end users and described as uploaded/local app data.

## Documentation

- `README.md` – administration and user guide.
- `README_API-Pop.md` – project overview and setup.
- `README_API-Pop_ES.md` – Spanish overview.
- `README_API-Pop_Dinamica_Trabajo_Colaborativo.md` – collaboration workflow.
- `Data_Dictionary_API-Pop.md` – standard case-record fields.
- `Data_Dictionary_API-Pop_cases.md` – filtered case export.
- `Data_Dictionary_API-Pop_weekly_pop.md` – weekly summary export.

## Deployment checklist

- Test valid and invalid file upload.
- Confirm upload review modal works.
- Confirm filters load from the configured data source.
- Confirm weekly export uses `n_cases`.
- Confirm no credentials are committed.
- Confirm no test data is committed in local data files.

## Project

**Project:** PPT-UK – Argentina Work Package WS5
**Institution / Delivery Partner:** CEMIC
