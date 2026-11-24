# API-POP | Reports Data Dictionary

**Applies to:** API-POP v2.x. **Revision:** 2026-11-23.

## Data-source expectations

API-POP queries a configured `reports` table (the name can be changed in `config.yaml`) and appends mapped uploads into that destination. The table schema is **not universally fixed**: it depends on the configured data source. The query in `R/main_analysis.R` expects the following fields and expressions.

| Field | Meaning | Used for |
|---|---|---|
| `suspected_diagnosis` | Diagnosis text supplied in the record. | Filtering, query and export. |
| `symptom_description` | Symptoms described in free text. | Filtering, query and export. |
| `symptom_onset_date` | Symptom onset date. | Exact/range filtering, query and export. |
| `consultation_date` | Consultation date. | Query, age computation and ISO-week aggregation. |
| `birth_date` | Birth date. | Derivation of calculated `Age` column. |
| `sex` | Sex/category stored in source. | Query and export. |
| `country` | Configured country name or key. | Geographic filtering and grouping. |
| `level1`, `level2`, `level3` | Configured geographic values. Level 1 and 2 may be names; level 3 may be a code. | Geographic filtering, grouping and population join. |
| `country_norm`, `level1_norm`, `level2_norm`, `level3_norm` | Internal normalized values added/backfilled where possible. | Text/geographic matching; not normal public export fields. |
| `id_code`, `email`, `institution`, `confirmation_time` | May be present in report imports/stores, but are **not selected** in the current case-query SQL. | Source record fields when available. |

The main query generates `Age` using a SQLite `julianday()` difference divided by `365.25` and cast to integer. Age therefore depends on the chosen consultation and birth dates and may differ from other age conventions.

## Schema considerations

`ensure_reports_schema()` can alter existing tables to add normalized geographic fields and backfill missing normalization values; opening this app is not purely read-only. The configured table must already contain the columns the main SELECT expects. Uploaded columns are mapped to available destination fields in the UI, and missing target columns are filled with `NA`; acceptance at staging is not a full record-quality validation.

## Related documentation

- [Developer Guide](DEVELOPER_GUIDE.md)
- [Institutional Setup Guide](INSTITUTIONAL_SETUP_GUIDE.md)
- [Filtered Cases Export Dictionary](Data_Dictionary_API-Pop_cases.md)
- [Weekly Summary Dictionary](Data_Dictionary_API-Pop_weekly_pop.md)
