# API-POP | Repository Description

R/Shiny application for reviewing and filtering suspected-case records, staging and mapping file uploads, and exporting filtered cases and weekly geographic `n_cases` with an optional population denominator from the configured GeoPackage.

**Current source:** v2.x family; `CITATION.cff` declares software version `2.0.1`. Deployment requires review of `config.yaml`, a compatible reports table and country GeoPackages. SQLite and ODBC connection helpers are present, but the query layer is not a universal database adapter.

## Documentation

- [User Guide](USER_GUIDE.md)
- [Institutional Setup Guide](INSTITUTIONAL_SETUP_GUIDE.md)
- [Developer Guide](DEVELOPER_GUIDE.md)
- [Data dictionary](Data_Dictionary_API-Pop.md)

See the [root README](../../README.md) for local startup cautions. Do not use live records or an unbacked-up database for initial testing.
