# API-POP v2.0 – Administration and User Guide

API-POP is an R/Shiny application for reviewing suspected-case records, filtering them by geography and demographics, and producing population-compatible outputs for epidemiological analysis.

Version 2.0 updates the app to align more closely with the RAP tool family, including CUSUM RAP, Geospatial RAP, and the Digital Dashboard.

## 1. Overview

API-POP v2.0 supports two complementary workflows:

1. **Upload files** into the app, review whether they are allowed or disallowed, and append valid records to the local app data store.
2. **Connect to an external database** configured by an administrator.

These workflows are not mutually exclusive. A deployment can use an external database and still allow users to upload additional files when that is appropriate.

## 2. Main features

- Dynamic geographic filters driven by `config.json`.
- Configurable geography labels such as Province/Department/Fraction or Region/LAD/MSOA.
- Multi-file upload review with allowed/disallowed status.
- Upload review table shown in a popup/modal to avoid cluttering the main sidebar.
- Local app data store for uploaded records.
- Optional external database connection for deployments.
- Filtered case-list export.
- Weekly case/population summary export using `n_cases`.
- Timestamped download filenames.
- Shared helper structure under `R/shared/`.
- Dashboard-aligned visual styling through `WWW/config.css`.

## 3. Project structure

```text
API-Pop/
├── app.R
├── global.R
├── config.json
├── config.yaml
├── R/
│   ├── main_analysis.R
│   ├── module_filters.R
│   ├── module_results.R
│   ├── module_upload.R
│   └── shared/
│       ├── config_helpers.R
│       ├── database_connection.R
│       ├── database_helpers.R
│       ├── export_helpers.R
│       ├── file_manager.R
│       ├── table_helpers.R
│       └── upload_validation.R
├── data/
│   ├── Argentina.gpkg
│   └── your_database.dba
├── data_prep/
│   ├── merge_layers.R
│   ├── connect_database_example.R
│   └── prepare_api_pop_database.R
└── WWW/
    ├── config.css
    └── PPT_cemic_images.svg
```

Some helper files may vary depending on the exact release branch, but the v2.0 structure should keep reusable logic in `R/shared/`.

## 4. Configuration

### Environment profile

The app can use `R_CONFIG_ACTIVE` to select a configuration profile.

Example `.Renviron`:

```text
R_CONFIG_ACTIVE=default
```

Use `default` for local testing and a deployment-specific profile for production.

### `config.yaml`

`config.yaml` controls deployment-level settings such as data source mode, database path, and file paths.

Recommended v2.0 structure:

```yaml
default:
  data_source:
    mode: "local"
    upload_enabled: true

  database:
    type: "sqlite"
    path: "data/your_database.dba"
    table: "reports"

  gpkg_name: "Argentina.gpkg"
  json_config_path: "config.json"
```

For an external database, use an administrator-managed profile. For example:

```yaml
production:
  data_source:
    mode: "external_database"
    upload_enabled: true

  database:
    type: "odbc"
    dsn: "API_POP_DB"
    table: "reports"

  gpkg_name: "Argentina.gpkg"
  json_config_path: "config.json"
```

### `config.json`

`config.json` controls country and geography mappings.

Example pattern:

```json
{
  "Argentina": {
    "name": "Argentina",
    "file_name": "Argentina.gpkg",
    "levels": ["country", "level1", "level2", "level3"],
    "mapping": {
      "level1": {
        "db_column": "level1",
        "display_name": "Province",
        "layer_name": "Province",
        "spatial_id": "cpr",
        "name_col": "nam"
      },
      "level2": {
        "db_column": "level2",
        "display_name": "Department",
        "parent_col": "cpr",
        "layer_name": "Department",
        "spatial_id": "cde",
        "name_col": "nam"
      },
      "level3": {
        "db_column": "level3",
        "display_name": "Fraction",
        "parent_col": "cde",
        "layer_name": "Fraction",
        "spatial_id": "link",
        "name_col": "nam"
      }
    }
  }
}
```

Use `name_col` for the spatial layer field that contains human-readable names.

## 5. Preparing the local app data store

For local testing, the default app data store is a SQLite-compatible `.dba` file:

```text
data/your_database.dba
```

Administrators can create or reset the local app data store with:

```r
setwd("path/to/API-Pop")
source("data_prep/prepare_api_pop_database.R")
```

The standard table name is:

```text
reports
```

If the local file contains test data, delete or replace it before preparing a release. Avoid committing a database file containing real or temporary test records.

## 6. Connecting to an external database

API-POP v2.0 includes `data_prep/connect_database_example.R` as a starting point for administrators.

The recommended pattern is:

1. Create a database table or view compatible with the `reports` structure.
2. Configure the database connection in `config.yaml`.
3. Test the connection outside Shiny first.
4. Start the app and confirm filters/results load from the configured source.
5. Keep `upload_enabled: true` if users should still be able to append uploaded files.

Do not commit credentials. Use `.Renviron`, environment variables, DSNs, or deployment secrets.

## 7. Preparing geographic data

Use `data_prep/merge_layers.R` to prepare a country `.gpkg` file with the required layers.

Each configured level in `config.json` should match:

- an existing `.gpkg` layer,
- a spatial ID column,
- a display/name column through `name_col`,
- and, for child levels, a parent column linking it to the level above.

## 8. End-user workflow

### Upload files

1. Open the upload section.
2. Select one or more supported files.
3. Review the upload summary.
4. Use **Review uploaded files** to open the popup with allowed/disallowed details.
5. Append valid active files.
6. Continue filtering and exporting results.

Supported formats should preserve the existing app behavior and may include CSV, Excel, XML, and local database files depending on installed packages and configuration.

### Filter records

Use the sidebar filters to select:

- country/geographic levels,
- sex,
- age range,
- diagnosis or symptom filters,
- symptom onset date range,
- and other available criteria.

### Download outputs

API-POP provides two main outputs:

- **Filtered case list**: detailed records matching the selected filters.
- **Weekly summary**: aggregated `n_cases` and population by year, week, and geography.

## 9. Styling and theme

The app theme is controlled mainly through:

```text
WWW/config.css
```
