# API-POP: Developer guide

**Audience:** maintainers, reviewers, and developers extending the application  
**Software release line:** API-POP v2.x; documentation reflects current application source  
**Documentation revision:** 23 November 2026  
**Scope:** implemented behaviour, code responsibilities, operational assumptions and known limitations

## 1. Purpose and current capabilities

API-POP is an R/Shiny application for viewing case reports from a configured `reports` table, applying demographic, text, date, and hierarchical geographic filters, and downloading filtered records or a weekly case-count summary. It also has a reviewed multi-file import path that appends mapped data into the configured table. A GeoPackage supplies administrative areas and, if present in the configured finest layer, a population field for the weekly summary.

The current release does not include a universal database-adapter layer, automatic cloud-to-local fallback or arbitrary destination-schema discovery. Database capabilities are limited to the supported implementations documented below.

## 2. Repository orientation

| File or directory | Responsibility |
|---|---|
| `app.R` | Shiny entrypoint; invokes `analysisUI()` and `analysisServer()`. |
| `global.R` | Packages, helper/module loading, configuration, database pool, shared constants and pool shutdown. |
| `R/main_analysis.R` | Main page composition and SQL query orchestration. |
| `R/module_filters.R` | Filter inputs, country/area dropdowns, and applied filter state. |
| `R/module_upload.R` | Upload modal, staging/review, mapping, and destination append. |
| `R/module_results.R` | Results table, case CSV export, and weekly summary generation. |
| `R/utils.R` | File readers, text normalisation, SQL filter construction, GeoPackage option lookup. |
| `R/shared/config_helpers.R` | Country and level configuration lookup. |
| `R/shared/database_helpers.R` | SQLite/ODBC configuration, connection, schema inspection, normalization/backfill. |
| `R/shared/upload_validation.R` | Supported extensions and staged-upload checks. |
| `R/shared/export_helpers.R` | CSV writing and timestamped filenames. |
| `R/shared/file_manager.R` | Upload metadata/size/date summaries. |
| `R/shared/table_helpers.R` | Standard DT table rendering. |
| `config.yaml` | Runtime profiles (`default`, `production`), data source mode and database settings. |
| `config.json` | Country-specific geographic levels, layers, identifiers, display labels. |
| `www/config.css` | UI visual tokens and application styles. |
| `www/docs/` | User, administrator and developer documentation and data dictionaries. |

The default country geometry path is `data/Argentina.gpkg`. Distributions must include the appropriate licensed reference file or an institution-approved alternate configured at deployment.

## 3. Startup and dependency graph

1. `app.R` sources `global.R`.
2. `global.R` attaches Shiny, spatial, database, upload, and formatting packages and sources shared helpers and feature modules.
3. `config::get(file = here::here("config.yaml"))` resolves the active profile. `config.json` is parsed into `ALL_CONFIGS`.
4. A database pool is opened with `connect_app_database()`. `ensure_reports_schema()` then adds/backfills geographic normalisation columns **and writes to the configured database**.
5. The server invokes `analysisServer()`, which starts upload, filter, query and result modules. `onStop()` closes the pool at application shutdown.

Core libraries used by the source include `shiny`, `shinyjs`, `jsonlite`, `sf`, `DT`, `DBI`, `RSQLite`, `pool`, `config`, `stringi`, `readxl`, `dplyr`, `here`, `xml2`, and `lubridate` (via qualified calls). ODBC mode additionally requires `odbc` and a working driver/DSN. No project-root dependency lockfile is currently maintained for this release.

## 4. Runtime flows

### 4.1 Filtering

`filtersUI()` renders *Run Query* and *Reset Selections*. `filtersServer()` builds input controls from the `columns` map in `global.R`. The available filters include symptoms, symptom onset date, suspected diagnosis, age and location. Geographic options cascade by country, province, department and fraction for the configured Argentina hierarchy.

`filtersServer()` returns a reactive filter object only after *Run Query*. `analysisServer()` constructs a SELECT from the reports table and passes the conditions to `add_filters_to_sql()`. `DBI::dbGetQuery()` returns the result; `resultsServer()` renders a DT table.

**Known limitation:** the source's age range is passed to the SQL builder even when its checkbox is off. Text logic with `OR` needs SQL-precedence regression tests. These issues should be corrected and tested separately; they are not documentation changes.

### 4.2 File upload and append

`uploadUI()` opens the upload flow. `uploadServer()` obtains one or more files, invokes `read_one_upload()`, and runs `validate_staged_upload()`. The user reviews statuses, selects eligible files, maps unmatched columns, and confirms *Append Active Files*. The mapped data is normalised and appended with `pool::dbAppendTable()`.

Advertised extensions: `.csv`, `.xlsx`, `.xml`, `.dba`, `.sqlite`, `.db`. The `.sqlite`/`.db` variants use the `.dba` reader, which expects a table named as the configured destination table. Validation is limited; *Allowed* does not mean all individual values are clinically or structurally correct. There is no transaction-level duplicate prevention shown in the upload module.

### 4.3 Export

`resultsServer()` implements `download_csv` and `download_summary_csv`. The first downloads the **SQL query result**, not the entire underlying table. The second derives ISO year and week from `consultation_date`, groups by available configured geography fields, and writes `n_cases`. A matching population field (`Population`, `population`, `pop`, `total_population`) in the finest GeoPackage layer may be joined; otherwise `population` stays missing. It is not an age/sex-adjusted denominator unless the source data and join actually support that interpretation.

## 5. Internal interface reference

| Entry point / helper | Defined in | Primary contract |
|---|---|---|
| `analysisUI(id)` / `analysisServer(id, con, gpkg_path)` | `R/main_analysis.R` | Compose application and execute query workflow. |
| `filtersUI(id)` / `filtersServer(id, columns, display_names, population_layers)` | `R/module_filters.R` | Build input controls and return applied reactive filters. |
| `uploadUI(id)` / `uploadServer(...)` | `R/module_upload.R` | Stage, map and append uploaded records. |
| `resultsServer(...)` | `R/module_results.R` | Display records and implement two CSV downloads. |
| `connect_app_database()` / `disconnect_app_database()` | `R/shared/database_helpers.R` | Open/close a DBI connection or pool. |
| `ensure_reports_schema()` / `backfill_report_norm_columns()` | `R/shared/database_helpers.R` | Mutate existing database columns and values. |
| `get_data_source_settings()` / `get_database_settings()` | `R/shared/database_helpers.R` | Resolve runtime options. |
| `valid_country_names()` / `get_mapping_config()` | `R/shared/config_helpers.R` | Resolve country/level geographic configuration. |
| `read_uploaded_file()` / `read_csv_safely()` | `R/utils.R` | Parse uploaded files with encoding handling. |
| `add_filters_to_sql()` / `fetch_options()` | `R/utils.R` | Add query conditions / read geographic choices. |
| `validate_staged_upload()` / `validate_database_ready_upload()` | `R/shared/upload_validation.R` | Check upload shape and essential content. |
| `write_csv_utf8()` / `timestamped_filename()` | `R/shared/export_helpers.R` | Write downloadable files. |

Roxygen2 blocks immediately above functions in `R/` are the authoritative per-function API notes for this source edition. Internal functions remain implementation details and are not a promise of external API stability.

## 6. Data and geography contracts

`reports` is the default configured table. Its required fields depend on queries and import mapping; common fields are `id_code`, `consultation_date`, `birth_date`, `sex`, `country`, `level1`, `level2`, `level3`, `symptom_onset_date`, `symptom_description`, and `suspected_diagnosis`. Geographic normalisation columns are created/updated by `ensure_reports_schema()`.

The weekly export uses `year`, `week`, configured country/geographic levels, `n_cases`, and `population`; if population data cannot be joined it may be `NA`. The current schema does **not** include canonical `geo_code`, `level*_code` or population-provenance fields. Adding such fields requires a separately tested compatibility change. See the corresponding data dictionaries for exact field interpretation.

Configuration keys are data-driven, but the current interface expects at most three geographic selectors and the default map paths assume `data/<configured file>`. Supporting a new country's spatial data requires verification of every layer, hierarchy and output join.

### Population reference data and geographic joins

The weekly export reads population from the GeoPackage layer mapped to the lowest configured geographic level. For the bundled Argentina configuration, that is the Fraction layer, identified by cod_indec. The source recognises Population, population, pop and total_population as possible population field names; it does not provide an arbitrary population-column mapping.

The export uses consultation_date to calculate ISO epidemiological year and week, groups report counts by the configured geographic hierarchy, and joins population by the report geographic key and spatial_id. One population value is a denominator for an area, not an amount to sum across reporting weeks. A missing or unmatched denominator remains missing.

Population figures are not automatically restricted to the selected sex or age range. Record the source year, geographic coverage and population definition separately. Validate the join with known area codes before drawing conclusions from rates.

### Using RapidCaseReport outputs

RapidCaseReport stores symptom_description and suspected_diagnosis as free-text entries. Identical clinical concepts can appear with different spellings, abbreviations and levels of detail. API-POP does not automatically standardise these terms into a validated clinical vocabulary.

Before filtering or aggregating records, use an institution-approved coding or data-cleaning procedure. Preserve original values where required by audit policy, document transformations, and check that the resulting classification is suitable for the intended epidemiological analysis.

### Related technical references

See www/docs/Data_Dictionary_API-Pop.md, Data_Dictionary_API-Pop_cases.md, and Data_Dictionary_API-Pop_weekly_pop.md for field-level descriptions. The repository README.md describes application setup, while the institutional setup guide describes geographic and storage configuration. These are repository-relative paths; no external GitHub address is assumed.

## 7. Versions, provenance and change management

| Location | Value or purpose in this baseline |
|---|---|
| `CITATION.cff` | Declares software version `2.0.1` and release date `2026-06-12`. |
| `config.yaml` | Contains runtime profiles, not a software version. |
| Existing Markdown introductions | Commonly use the shorter `v2.0` label. |
| `CITATION.cff` `cff-version` | Set to `1.2.0`, the Citation File Format schema version; distinct from the software `version` field. |

The repository does not currently provide a verified chronological changelog for past versions. Do not infer release history from filenames or internal notes. Going forward, record a version identifier, release date, functional changes, migration requirements, and test results together in release notes. Reconcile `CITATION.cff`, UI labels and README when a new release is approved.

## 8. Maintenance and test strategy

Keep queries in the analysis/server utilities, upload validation in the upload helpers, and country mappings in `config.json`. Avoid appending nontrivial logic to `global.R` or mixing form/UI code with SQL construction. Design a complete change before modifying interconnected modules.

**Minimum checks for each release:**

1. Parse every application R file and launch in a clean R session.
2. Confirm the configured database path/table before startup; start only on an authorised **backup or test database**, because startup may alter its schema.
3. Verify country selection, cascading area choices, and leading-zero geographic codes against the real GeoPackage.
4. Test empty and populated queries; symptom `AND`/`OR`, age filter disabled/enabled, exact/range date filters.
5. Exercise file staging, disallowed formats, mapping, rejected rows, append errors, and duplicate imports.
6. Compare downloaded case rows with query rows; verify ISO weeks, grouping keys and missing-population cases.
7. Review access controls, privacy of report data, and deployment logging before public exposure.

**Known pre-release issues to track separately:** SQL precedence, age filter activation, upload error recovery, incomplete per-row import validation, database initialization side effects, and reliability of population joining. The existing source is not a generalized adapter for arbitrary external schemas.

## 9. Documentation and handover

- **Institutional Setup Guide:** configure databases, geographic assets, country mappings, style, and deployment safety.
- **User Guide:** upload, filter, review and export without internal implementation details.
- **Data dictionaries:** field names and output interpretation.
- **README.md:** entrypoint, installation overview and pointers to the three guides.

When a feature is changed, update its Roxygen2 block, relevant dictionary, user/admin guide, and release notes in the same change set. Do not document planned functionality as available.

## Appendix A. Change-impact reference

Use this matrix to identify the complete set of places that normally need review when a feature changes. The listed files are ownership guides; they are not substitutes for checking references and regression tests.

| Change | Source files to review | Expected regression evidence |
|---|---|---|
| Add a new case filter | `global.R`, `R/module_filters.R`, `R/main_analysis.R`, `R/utils.R` | UI control, enabled/disabled state, query SQL and row count. |
| Add a new upload format | `R/shared/upload_validation.R`, `R/module_upload.R`, `R/utils.R` | Correct reader selection, staged status, mapping and rejected invalid files. |
| Add or rename a case-record field | Reports table, `global.R`, `R/main_analysis.R`, upload helpers, dictionaries | Existing source query and append remain compatible, export fields documented. |
| Add a country or geographic level | `config.json`, GeoPackage, `R/module_filters.R`, `R/utils.R`, export logic | Every parent-child transition, identifier padding and spatial join. |
| Change weekly summary fields | `R/module_results.R`, weekly data dictionary, downstream RAP import contracts | ISO year/week, grouping keys, missing denominators and empty exports. |
| Change data-source technology | `config.yaml`, `R/shared/database_helpers.R`, SQL builder in `R/utils.R` | Connection, compatible SQL syntax, permissions, cleanup and rollback. |
| Change visual identity | `www/config.css`, `R/main_analysis.R`, shared UI components | Responsive layout, readable controls, keyboard access and branding consistency. |

A maintainable release should keep code, schema expectations, administrator instructions, user-facing wording and tests synchronized. Changes to a field's meaning or geographic key require an explicit compatibility review; renaming a label is not the same operation as migrating stored data.

### Suggested lightweight development checks

Run these from the project root after installing the required packages, against isolated synthetic test data:

```r
# Syntax check only: does not start the app or touch the database.
r_files <- c("app.R", "global.R", list.files("R", "\\.R$", recursive = TRUE, full.names = TRUE))
invisible(lapply(r_files, parse))

# Interactive smoke test: may initialize or alter the configured database.
# Configure a disposable copy before running.
shiny::runApp(".")
```

The parser check only establishes syntactic validity. It cannot establish successful database access, correct SQL, geographic joins or clinical-data safety. Keep a reproducible set of synthetic records with known expected query and export results for functional tests.
