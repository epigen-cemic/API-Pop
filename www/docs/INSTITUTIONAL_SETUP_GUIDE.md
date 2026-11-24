# API-POP: Institutional setup and country configuration

**Audience:** IT staff, application administrators and institutional implementers  
**Software release line:** API-POP v2.x  
**Documentation revision:** 23 November 2026

## 1. What is configurable today

API-POP reads report records from a configured SQLite database or a DBI/ODBC connection and uses GeoPackage layers to populate geographic filters. It supports multi-file upload and append into the selected reports table. The application does not yet negotiate arbitrary database schemas or discover write permissions automatically. **Connecting successfully does not prove the app can query or append data.**

This guide describes currently supported database and geographic configuration only. For hosted deployments, use a separately configured environment and backup strategy; do not test against live clinical data.

## 2. Prepare an institutional deployment

1. Make a protected copy of the project and identify its working directory (the directory with `app.R`, `global.R` and `config.yaml`).
2. Review local privacy, clinical-data retention, authentication and hosting requirements. This source does not implement a user-account or role-based authorisation layer.
3. Prepare a **test** `reports` table with the expected columns and a geographic reference file. Use synthetic records first.
4. Confirm database write privileges **before launch**. Current startup can add geographic normalisation columns and backfill records; it is not a read-only probe.
5. Install the required R packages and system dependencies, especially the spatial stack for `sf`, `RSQLite`, and any ODBC driver/DSN.
6. Run `shiny::runApp(".")` from the project root only after configuration is reviewed.
7. Complete the acceptance checklist in section 8 before switching to real institutional records.

## 3. Runtime configuration: `config.yaml`

Two existing profiles, `default` and `production`, specify similar settings. Select the runtime profile using the standard `config` package environment selection (for example, `R_CONFIG_ACTIVE=production`) **before starting** Shiny.

```yaml
# Example for a pre-existing local test database; replace the example path.
default:
  json_config_path: "config.json"
  gpkg_name: "Argentina.gpkg"
  data_source:
    mode: "local"
    upload_enabled: true
  database:
    type: "sqlite"
    path: "data/example_test_reports.sqlite"
    table: "reports"
```

| Setting | Meaning / restriction |
|---|---|
| `json_config_path` | Country-hierarchy configuration file relative to project root. |
| `gpkg_name` | Default GeoPackage name used in app-level path initialization. |
| `data_source.mode` | Display/configuration mode (`local` or `external_database`); this is not a storage failover system. |
| `data_source.upload_enabled` | Enables the upload workflow in the interface. |
| `database.type` | `sqlite` or `odbc` in this source. |
| `database.path` | SQLite file path; **connecting can create a new file** if missing. |
| `database.table` | Table name used for reads and appends; defaults to `reports`. |
| `database.dsn` | Required in ODBC mode; driver and DSN must already exist in the host environment. |
| `database.uid` / `database.pwd` | ODBC credentials; avoid storing them in committed configuration. Environment variables `API_POP_DB_UID` and `API_POP_DB_PWD` are supported when these fields are absent. |

**Important:** API-POP constructs SQL containing SQLite-specific expressions (including `julianday`). ODBC connection support is present, but this query layer has not been made database-dialect independent; compatibility must be tested with the chosen server. The app may attempt schema modification on startup even when a data source is intended to be read-only.

## 4. Geographic configuration: `config.json`

The country name is a top-level key. Each actual country entry needs `name`, `file_name`, an ordered `levels` list, and a `mapping` for each level. The active implementation uses generic keys `country`, `level1`, `level2`, `level3`. Example identifiers below are from the bundled Argentina configuration—not a template for other countries.

| Level | Layer | `spatial_id` | `parent_col` | `name_col` | `code_length` |
|---|---|---|---|---|---|
| `level1` | `Province` | `cpr` | — | `nam` | 2 |
| `level2` | `Department` | `cde` | `cpr` | `nam` | 5 |
| `level3` | `Fraction` | `cod_indec` | `cde` | `cod_indec` | 7 |

The corresponding `db_column` values in API-POP are `level1`, `level2`, `level3`; `ui_label` provides human-readable labels. Leave the configured code lengths as **text** to preserve leading zeros.

### Adding a new country

1. Obtain authoritative administrative boundaries under an appropriate licence and verify their CRS and coverage. This repository does not include a working geographic-data merge script.
2. Create a GeoPackage with one validated layer per level. Each lower-level layer must contain its own ID and a usable parent ID; names may repeat, IDs must be unique within their intended scope.
3. Place the file under `data/` using the filename declared in `config.json`.
4. Add the country entry with its ordered levels, layer names, `spatial_id`, `parent_col`, `name_col`, `db_column`, `code_length`, and `ui_label`.
5. Ensure `database.table` and the actual reports fields match the `db_column` values; changing UI labels does not rename database columns.
6. Update `gpkg_name` if the app-level default path needs to change. Note that the filter module separately constructs `data/<country file_name>` paths.
7. Test country selection, parent-child filtering, the final area code, query results, and population joins on known synthetic records. Do not treat a visible dropdown as proof of a correct join.

The current filter UI has controls for three levels; hierarchies longer than three levels or incompatible identifier formats require source changes and regression tests.

## 5. Populations and weekly data

The weekly export counts filtered report rows by ISO `year`/`week` based on `consultation_date` and configured geography. It attempts to join a population column from the finest configured geographic layer, accepting the names `Population`, `population`, `pop`, or `total_population`.

**Do not assume** the join succeeds for an arbitrary new country. The case-level geographic value must match the `spatial_id` type and padded code representation; missing population remains missing in the output. The source does not select among multiple population vintages, and a matching population value is not automatically stratified by the selected age and sex. Validate population provenance and aggregation level independently before using rates.

### Prepare population reference data

Provide a numeric population field in the configured GeoPackage layer for the lowest geographic level. For Argentina, that is the Fraction layer. Use a field named Population, population, pop or total_population, because the current exporter searches for those names.

For each geographic record, the spatial_id must match the identifier stored in the reports table, including any leading zeros. If population is held in a separate administrative dataset, verify and join it to the relevant GeoPackage layer before running the current exporter. Do not assume that adding a separate CSV population file enables a join.

Record the population source, reference year, coverage, and whether values represent all residents or an eligible subgroup. Current exports do not select population by reference year and do not automatically adjust denominators for demographic filters.

### Validate transfer from RapidCaseReport

Review imported symptom_description and suspected_diagnosis values before analysis. These fields are free text and may contain synonyms, local abbreviations and inconsistent spellings. Agree a terminology and validation policy with clinical or surveillance leads, and preserve an audit trail for any data cleaning.

## 6. Adding or importing institutional case data

An administrator may pre-populate the configured reports table outside Shiny, or users may upload through the UI. Uploads are **appended**, not merely previewed. The UI advertises CSV, XLSX, XML and SQLite-family files. Use staged files with one case per row and standard fields where possible.

Recommended procedure: load synthetic rows, open *Upload Files*, review the allowed/disallowed status, select active files, map unmatched columns, click *Append Active Files*, then verify the destination row count in a trusted database tool. Repeat the same file only in a test environment because duplicate detection is not guaranteed.

A local SQLite file is not a good shared multi-user data store over a network filesystem. The deployment team must control concurrent writes, filesystem backups, retention and access permissions. Do not commit real case data into the project repository.

## 7. UI, branding and maintenance

`www/config.css` controls the shipped theme; start with its `:root` variables. The title and UI labels are in `R/main_analysis.R`, standard filter labels in `global.R`, and country/level labels in `config.json`. The application uses the shipped `www/AnalysisforAction_white.png` asset. Check contrast and mobile layouts after changing colors. Do not modify analytical SQL while making branding changes.

Keep documentation consistent with `CITATION.cff` and the application source. The software version recorded in `CITATION.cff` is `2.0.1`, while some earlier publications used the broader `v2.0` name; adopt a single approved version when publishing updated documentation. No verified historical changelog is provided.

### Institutional security responsibilities

The deployed institution is responsible for authentication, access permissions, secure handling of database credentials, data protection, export controls, retention and backups. The demonstration configuration is not a complete production security model. Review system permissions and clinical-data governance before enabling real submissions or downloads.

## 8. Deployment acceptance and troubleshooting

| Check | What must be demonstrated |
|---|---|
| Startup | App starts without writing to an unintended or placeholder database. |
| Geographic hierarchy | Country and child areas resolve using the intended GeoPackage layers and parent codes. |
| Query | A known synthetic record is returned only by intended filters, including text OR combinations and age toggle. |
| Upload | Wrong formats rejected; mapping reviewed; actual append confirmed; failures visible. |
| Export | Cases CSV matches filtered query; weekly CSV has correct ISO weeks, counts and null denominators. |
| Database safety | Backups exist; connection and migration privileges are explicitly authorized. |
| Privacy | Data access, logs and downloads comply with institutional governance. |
| Packaging | Required geographic files, drivers, CSS and documentation are distributed outside source-control secrets. |

**If the app creates an unexpected empty SQLite file:** stop, inspect `config.yaml` and `R_CONFIG_ACTIVE`, and confirm the configured path. **If an area list is empty:** check `config.json` keys and GeoPackage layer/parent columns. **If summary population is empty:** inspect the finest layer's population field and key agreement. **If an external DB connects but queries fail:** check SQL dialect, mapped schema and permissions rather than assuming network failure.

## 9. Responsibility boundary

Users of the application should not need to edit code or databases. Institutional implementers own configuration, data integrity, access controls, backups, geographic/reference data and release verification. Developers own code changes, tests and updated function-level Roxygen2 documentation. Universal schema mapping and automatic database failover are not available in this release.
