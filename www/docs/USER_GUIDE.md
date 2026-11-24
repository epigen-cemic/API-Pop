# API-POP: User guide

**Audience:** analysts and public-health professionals using the application interface  
**Documentation revision:** 23 November 2026

## 1. What you can do

API-POP helps you explore available suspected-case records, narrow them with filters, view a results table, and download either filtered cases or a weekly case-count summary. Data availability and which countries are shown depend on your institution's configuration.

You do not need to understand databases or edit configuration files. If the app cannot open or no data is available, contact your institution's application administrator.

## 2. Understand the screen

| Area | What it is for |
|---|---|
| **Data** | Open the file-upload workflow, if enabled. |
| **Filter by** | Choose which case fields to filter. |
| **Run Query** | Apply your currently selected filters and refresh results. |
| **Reset Selections** | Clear selections so you can prepare another query. |
| **Query results** | Inspect the records returned by the query. |
| **Cases List** | Download the filtered query records as CSV. |
| **Weekly Summary** | Download a weekly count summary as CSV. |

The results table is an interactive display; downloading cases exports the query result, which can include fields not visible in the condensed table.

## 3. Uploading records (when enabled)

1. Select **Upload Files** under *Data*.
2. Choose one or more files. The interface currently accepts `.csv`, `.xlsx`, `.xml`, `.dba`, `.sqlite`, and `.db`; not every file of these types is necessarily compatible with your institution's records table.
3. Select **Review Files**. Inspect the status and messages for each file.
4. Select the allowed files you want to append, then select **Continue to Mapping**.
5. For an uploaded column that has no exact match, choose the corresponding app data field or leave it ignored.
6. Review the selections and select **Append Active Files** only when you intend to add those records to the current data source.
7. Check the success notification or consult an administrator if an append error occurs.

**Important:** append is a write action. It is not just loading files into a temporary chart. Avoid re-uploading the same records without checking for duplicates. The *Review uploaded files* dialog describes files handled in the current session, not a complete database audit.

## 4. Applying filters

Each filter has a checkbox. Select the checkbox for the criteria you want, then enter its value. When ready, select **Run Query**; changing a control alone does not necessarily rerun the data query.

- **Symptoms:** enter a symptom or combine terms using the *AND* and *OR* controls. Mixed conditions can produce unexpected matches in this version. Review returned records or ask your administrator to check the results before using them for analysis.
- **Symptoms Onset Date:** choose an exact date or a date range.
- **Diagnosis:** enter the suspected diagnosis text.
- **Age:** use the age-range slider for the intended range. In this version the displayed range may affect results even when the age filter is not selected. Check the age coverage with your administrator before relying on counts.
- **Location:** select a country, then any required province, department and census fraction. The available levels are configured by the institution, and selecting a parent limits the child options.

You can leave geographic selection broad when you do not need a specific area. Select **Reset Selections** to begin a different query; run the new query afterward.

## 5. Reading and exporting results

After **Run Query**, inspect *Query results*. An empty table may mean there are no matching records, or that one of the filters is more restrictive than expected. Recheck the selected criteria before interpreting an empty result as no reported cases.

- **Cases List** creates a timestamped CSV containing the filtered query records.
- **Weekly Summary** creates a timestamped CSV with ISO year/week, geographic grouping, `n_cases`, and population when a matching population source is available.

`n_cases` is a count, not a prevalence or incidence rate. A blank `population` field means the source could not provide a matching denominator; do not interpret it as zero. Population is not necessarily adjusted to your selected demographic subgroup. Confirm eligibility and denominator definitions before calculating rates or comparing areas.

## 6. Troubleshooting

| Symptom | What to do |
|---|---|
| No countries or areas appear | Contact the administrator; geographic configuration or reference files may be missing. |
| Uploaded file is marked disallowed | Check its format, contents and error message. |
| A column cannot be mapped | Confirm its meaning with the source data owner; do not guess for clinical or geographic fields. |
| Results are unexpectedly empty | Run a broader query, check age/date selections, then ask for verification. |
| Weekly population is blank | Continue with count interpretation only or ask the data custodian about denominators. |
| Saving/appending fails | Do not repeat automatically; contact your administrator and check whether records were inserted. |

### Interpreting text-based filters

Symptoms and suspected diagnoses may be entered in different ways. A search for one spelling or clinical term may not find records that use an abbreviation or another term. Check which terms your institution uses before relying on filtered results.

Population values in weekly downloads refer to the configured geographic areas. They may not match the age or sex of the cases selected. Ask your analysis lead to confirm the denominator before calculating or comparing rates.

## 7. Data quality and privacy

These records may contain sensitive information. Follow your organisation's access and export policies, store downloaded files securely, and avoid sharing record-level data through unauthorized channels. API-POP supports surveillance analysis; findings should be interpreted with the known limits of case reporting, geographic assignment and population coverage.
