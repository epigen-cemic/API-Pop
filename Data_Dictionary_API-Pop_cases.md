# Data Dictionary – API-POP v2.0 Filtered Case Export

This dictionary describes the filtered case-list export produced by API-POP v2.0.

The case export is intended for review, audit, and downstream investigation. It contains the records matching the selected filters. Internal normalized columns are not intended for the user-facing export.

## Standard exported fields

| Field name | Type | Format / allowed values | Description |
|---|---:|---|---|
| `id_code` | Text | UUID or source identifier | Unique source record identifier when available. |
| `consultation_date` | Date | `YYYY-MM-DD` | Date of consultation or report contact. |
| `symptom_onset_date` | Date | `YYYY-MM-DD` | Date when symptoms began. |
| `suspected_diagnosis` | Text | Free text or configured category | Suspected diagnosis or event label. |
| `symptom_description` | Text | Free text | Description of symptoms. |
| `country` | Text | Configured country name/code | Country associated with the case location. |
| `level1` | Text | Configured geography code/name | First configured administrative/geographic level. |
| `level2` | Text | Configured geography code/name | Second configured administrative/geographic level. |
| `locality` | Text | Free text or configured location value | Locality or place name when available. |
| `level3` | Text | Configured geography code/name | Third configured administrative/geographic level, when available. |
| `sex` | Text | Source value | Sex or sex category recorded for the case. |
| `birth_date` | Date | `YYYY-MM-DD` | Date of birth when available. |
| `email` | Text | Email address | Reporting professional or submitter email when available. |
| `institution` | Text | Free text | Reporting institution when available. |
| `confirmation_time` | Date-time | `YYYY-MM-DD HH:MM:SS` | Date-time when the record was submitted or confirmed by the source tool. |

## Notes

- The exact column order may vary slightly depending on the source data and app configuration.
- Internal columns such as `country_norm`, `level1_norm`, `level2_norm`, and `level3_norm` are used for filtering and should normally remain hidden from the exported case list.
- In v2.0, downloads should use timestamped filenames to avoid overwriting multiple exports created on the same day.
- Geographic labels shown in the app are controlled by `config.json`; exported data keeps the standard generic field names for compatibility with the other RAP tools.
