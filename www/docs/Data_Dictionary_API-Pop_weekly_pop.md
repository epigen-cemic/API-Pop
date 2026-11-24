# API-POP | Weekly Case Summary Dictionary

**Applies to:** API-POP v2.x. **Revision:** 2026-11-23.

**Weekly Summary** downloads CSV produced by `resultsServer()`. Counts are grouped by ISO week and the geographic fields present in the filtered query. The default Argentina hierarchy is country, level1, level2 and level3; other configured hierarchies can produce a different geographic column set.

| Field | Type | Meaning |
|---|---|---|
| `country`, `level1`, `level2`, `level3` | Text | Available configured geographic grouping fields (not all guaranteed for every country). |
| `year` | Integer | ISO week-based year from `consultation_date` (`lubridate::isoyear`). |
| `week` | Integer | ISO week number from `consultation_date` (`lubridate::isoweek`), 1–53. |
| `n_cases` | Integer | Number of filtered case rows in that geographic unit and week. |
| `population` | Numeric/nullable | Population from a matching field in the finest configured geographic layer, when join succeeds. |

**Population join:** the program reads the configured finest-level GeoPackage layer, looks for `Population`, `population`, `pop` or `total_population`, and joins using the configured `spatial_id` and its `db_column` counterpart. If no usable layer, field or join exists, `population` may be blank/`NA`. Blank is **not** zero. The source does not calculate demographic-specific denominators or manage population reference years.

**Granularity:** one row for each distinct ISO week + combination of available geographic columns. This source does not automatically deduplicate the underlying case data before counting. `n_cases` is a count, not prevalence. The join and correct geography must be validated before passing the summary to RAP CUSUM, Geospatial or Dashboard.

An empty or incompatible query may produce a header-only CSV. The application uses a timestamped `weekly_summary` filename.

## Preparing the population reference

For the bundled Argentina configuration, population should be stored in the finest mapped GeoPackage layer, **Fraction**, with a unique `cod_indec` identifier. The current exporter recognises `Population`, `population`, `pop`, or `total_population`. If a population dataset is separate, it must be validated and joined to the layer before the exporter can use it.

Record the population source, reference year, geographic coverage and eligible population definition outside the current weekly CSV. The exporter does not resolve multiple population vintages, and the denominator is not automatically adjusted for the sex or age filters selected. Missing values are not zero.
