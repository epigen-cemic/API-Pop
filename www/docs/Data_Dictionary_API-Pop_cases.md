# API-POP | Filtered Case Export Dictionary

**Applies to:** API-POP v2.x. **Revision:** 2026-11-23.

The **Cases List** button runs the same filtered query used to feed the results UI, then downloads those query columns as CSV. This is **not** a full-table export. It is not the same as the condensed interactive results display.

| Field | Type/meaning | Conditions |
|---|---|---|
| `suspected_diagnosis` | Text | As returned by the configured reports table. |
| `symptom_description` | Text | May contain multiple symptoms. |
| `symptom_onset_date` | Date/text representation | Subject to source data type and SQL engine. |
| `country` | Text | Included through configured geography. |
| `level1` | Text | Included when in selected/configured hierarchy. |
| `level2` | Text | Included when in selected/configured hierarchy. |
| `level3` | Text | Included when in selected/configured hierarchy. |
| `consultation_date` | Date/text representation | Drives the weekly export. |
| `sex` | Text | Original source category. |
| `Age` | Integer derived from consultation/birth dates | May be missing for incomplete dates. |

The actual exported geographic columns depend on the country configuration and current query. `id_code`, `birth_date`, `email`, `institution` and source timestamps are not part of the current SELECT, even if they exist in the database. Output filenames use a timestamped `query_results` prefix.

**Important:** records should be handled according to institutional confidentiality and access policies. See the [User Guide](USER_GUIDE.md) for downloading and interpreting results.
