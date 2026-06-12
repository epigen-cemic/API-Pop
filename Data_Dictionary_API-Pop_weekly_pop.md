# Data Dictionary – API-POP v2.0 Weekly Case and Population Summary

This dictionary describes the weekly summary export produced by API-POP v2.0.

The weekly summary is the main compatibility output for downstream RAP tools such as CUSUM RAP, Geospatial RAP, and the Digital Dashboard.

## Standard exported fields

| Field name | Type | Format / allowed values | Description |
|---|---:|---|---|
| `year` | Integer | `YYYY` | Epidemiological or calendar year used by the aggregation. |
| `week` | Integer | `1`-`53` | Week number used by the aggregation. |
| `country` | Text | Configured country name/code | Country associated with the aggregated location. |
| `level1` | Text | Configured geography code/name | First configured administrative/geographic level. |
| `level2` | Text | Configured geography code/name | Second configured administrative/geographic level. |
| `level3` | Text | Configured geography code/name | Third configured administrative/geographic level, when available. |
| `n_cases` | Integer | `0` or greater | Number of filtered cases for the location and week. |
| `population` | Numeric | `0` or greater | Population denominator for the location and selected demographic filters, when available. |

## Compatibility notes

- The case-count column is `n_cases` in v2.0. Do not rename it to `Recount` or `cases` for new exports.
- Downstream RAP tools should treat `n_cases` as the event count column.
- If a configured geography level is not used by a country or source dataset, the corresponding level column may be blank or omitted depending on the app configuration.
- Population values should be numeric and should represent the denominator corresponding to the selected filters.
- Downloads should use timestamped filenames to avoid overwriting multiple exports created on the same day.

## Minimal compatible structure

A minimal weekly export for downstream analysis should contain:

```text
year,week,country,level1,level2,level3,n_cases,population
2026,6,Argentina,Buenos Aires,La Plata,,12,150000
2026,7,Argentina,Buenos Aires,La Plata,,15,150000
2026,8,Argentina,Buenos Aires,La Plata,,10,150000
```

When level 3 is active and available, `level3` should be filled with the configured third-level code or name.
