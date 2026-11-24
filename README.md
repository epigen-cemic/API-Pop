# API-POP

API-POP is an R/Shiny application for filtering case reports, reviewing uploaded files, appending mapped records to a configured data source, and exporting filtered cases and ISO-week case counts. Geographic levels and labels are configured per country. Weekly exports may include a population denominator from a configured geographic layer when the join succeeds.

**Software release line:** v2.x (`CITATION.cff` identifies software version `2.0.1`). **Documentation revision:** 2026-11-23. This README documents currently implemented functionality.

## Quick start

1. Review `config.yaml` for the correct `default`/`production` profile and **authorized** database path. It currently includes example-looking database names; connecting can create an empty SQLite file and the app may modify the reports table schema.
2. Ensure the configured GeoPackage is present in `data/` and matches `config.json`.
3. Install the packages loaded by `global.R` and required system libraries, including the spatial dependencies of `sf`.
4. Open the project root in RStudio and run `shiny::runApp(".")` on a **test data source** first.
5. Confirm geographic filters, an expected query, and both CSV exports before using real data.

## Main modules

`app.R` → `global.R` → `R/main_analysis.R`. The upload, filters and results components reside in `R/module_upload.R`, `R/module_filters.R`, and `R/module_results.R`. Shared helpers are under `R/shared/`; data and SQL helpers also live in `R/utils.R`. Presentation is controlled by `www/config.css`.

## Documentation by audience

- [Documentation index](www/docs/DOCUMENTATION_INDEX.md)
- [User Guide](www/docs/USER_GUIDE.md) (`www/docs/API-Pop_User-Guide.docx`)
- [Institutional Setup and Country Configuration](www/docs/INSTITUTIONAL_SETUP_GUIDE.md)
- [Developer Guide](www/docs/DEVELOPER_GUIDE.md)
- [Reports data dictionary](www/docs/Data_Dictionary_API-Pop.md)
- [Filtered cases CSV](www/docs/Data_Dictionary_API-Pop_cases.md)
- [Weekly summary CSV](www/docs/Data_Dictionary_API-Pop_weekly_pop.md)

## Current limitations

The application does not provide a universal database-adapter or offline failover layer. ODBC connection code exists but query SQL includes SQLite-specific expressions. Startup can alter the configured reports schema. Review SQL `AND`/`OR` precedence, age filter activation, upload error reporting and population joins before final release. A reproducible automated application test suite should be added before an institutional production release.

## Data governance

Do not commit clinical records, credentials, local databases, geographic data without appropriate distribution rights or secret environment files. Deploy with institution-approved identity, network, storage, retention, backup and export policies.
