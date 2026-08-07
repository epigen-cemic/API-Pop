# Data Dictionary – API-POP v2.0

This dictionary describes the standard case-record structure used by API-POP v2.0.

API-POP can work with two complementary data sources:

1. **Uploaded files** reviewed and appended during an app session.
2. **An external database connection** configured by an administrator.

For the normal user workflow, the internal storage layer should be treated as **local app data**, not as a user-facing database. The same field structure should be used by any compatible external database table or view.

## Recommended table/view

| Item | Value |
|---|---|
| Standard table/view name | `reports` |
| Purpose | Stores suspected-case records used for filtering and weekly aggregation |
| User-facing wording | Local app data / configured data source |
| Primary identifier | `id_code` where available |
| Downstream outputs | Filtered case list and weekly `n_cases` summary |

## Standard fields

| Field name | Type | Format / allowed values | Required | Description |
|---|---:|---|---:|---|
| `id_code` | Text | UUID or source identifier | Recommended | Unique identifier for each source record. If absent in uploads, the app may create or preserve a generated identifier depending on the import path. |
| `consultation_date` | Date | `YYYY-MM-DD` | Recommended | Date of consultation or report contact. |
| `sex` | Text | `M`, `F`, `Other`, `Rather not say`, or source-specific values | Recommended | Sex or sex category recorded for the case. |
| `birth_date` | Date | `YYYY-MM-DD` | Recommended | Date of birth. Used for demographic filtering when available. |
| `country` | Text | Configured country name/code | Yes | Country associated with the case location. |
| `level1` | Text | Configured geography code/name | Recommended | First configured administrative/geographic level. For Argentina this is usually Province. |
| `level2` | Text | Configured geography code/name | Recommended | Second configured administrative/geographic level. For Argentina this is usually Department. |
| `locality` | Text | Free text or configured location value | Optional | Locality or place name when available. |
| `level3` | Text | Configured geography code/name | Optional/Recommended | Third configured administrative/geographic level. For Argentina this is usually Fraction. |
| `symptom_onset_date` | Date | `YYYY-MM-DD` | Recommended | Date when symptoms began. Used for date filtering and weekly aggregation. |
| `symptom_description` | Text | Free text | Optional | Description of reported symptoms. |
| `suspected_diagnosis` | Text | Free text or configured category | Optional | Suspected diagnosis or event label. |
| `confirmation_time` | Date-time | `YYYY-MM-DD HH:MM:SS` | Recommended | Date-time when the record was submitted or confirmed by the source tool. |
| `email` | Text | Email address | Optional | Reporting professional or submitter email where applicable. |
| `institution` | Text | Free text | Optional | Reporting institution or organization where applicable. |
| `country_norm` | Text | Normalized value | Internal | Normalized country value used for robust filtering. |
| `level1_norm` | Text | Normalized value | Internal | Normalized level 1 value used for robust filtering. |
| `level2_norm` | Text | Normalized value | Internal | Normalized level 2 value used for robust filtering. |
| `level3_norm` | Text | Normalized value | Internal | Normalized level 3 value used for robust filtering. Required for level 3 filters to work reliably. |

## Notes on geographic fields

API-POP v2.0 uses generic geography fields (`country`, `level1`, `level2`, `level3`) so the same code can support different countries and administrative structures.

Display names are configured in `config.json`. For Argentina, the default display labels normally correspond to:

| Generic field | Argentina display label |
|---|---|
| `country` | Country |
| `level1` | Province |
| `level2` | Department |
| `level3` | Fraction |

Other countries may use different labels, such as Region, LAD, MSOA, municipality, district, or other administrative units.

## Normalized columns

The `*_norm` columns are internal helper columns. They make filtering more reliable by reducing differences caused by case, spaces, accents, or small formatting changes. They should not normally be shown to end users or exported as public analysis columns.

## Upload compatibility

Uploaded files should contain equivalent case-record columns. The app may standardize accepted column names during import. Supported upload formats depend on the installed packages and current app configuration, but the v2.0 workflow is designed to preserve the previously supported formats, including CSV, Excel, XML, and local database files where enabled.

## External database compatibility

When using an external database, administrators should expose a table or view compatible with the standard `reports` structure above. The app can still allow file uploads while connected to an external database, so the two workflows are complementary rather than mutually exclusive.
