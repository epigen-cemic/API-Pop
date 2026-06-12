# API-POP v2.0 – Collaborative Development Workflow

This document describes the recommended workflow for collaborators working on API-POP.

## 1. Clone the repository

First-time setup:

```bash
git clone https://github.com/epigen-cemic/API-Pop.git
cd API-Pop
```

Or in RStudio:

1. `File > New Project > Version Control > Git`
2. Paste the repository URL.
3. Choose a local folder.
4. Open the project.

## 2. Pull before starting work

Before editing:

```bash
git pull
```

In RStudio, use the Git tab and click **Pull**.

## 3. Work on a branch when possible

Recommended:

```bash
git checkout -b feature/short-description
```

Examples:

```bash
git checkout -b feature/upload-review-modal
git checkout -b fix/level3-normalisation
git checkout -b docs/v2-release
```

## 4. Edit and test locally

Typical local test:

```r
setwd("path/to/API-Pop")
shiny::runApp()
```

Minimum v2.0 checks before committing:

- App starts without errors.
- Upload section loads.
- Valid file upload works.
- Invalid file upload is shown as disallowed.
- Upload review opens in a popup/modal.
- Geographic filters load.
- Level 3 filtering does not produce `level3_norm` errors.
- Filtered case export downloads.
- Weekly summary export includes `n_cases`.
- Download filenames include a timestamp.

## 5. Do not commit local/private data

Do not commit:

```text
.Rhistory
.RData
.Rproj.user/
.Renviron
.env
credentials
password files
local production databases
test databases containing real or temporary records
```

The file `data/your_database.dba` should only be committed if the team intentionally maintains an empty sample local app data store. Do not commit it after adding test or live data.

## 6. Config and secrets

Use these files carefully:

| File | Commit? | Notes |
|---|---:|---|
| `config.json` | Yes | Country/geographic mappings and display labels. |
| `config.yaml` | Usually yes | Safe defaults only. No secrets. |
| `.Renviron` | No | Local profile variables, credentials, DSNs, or tokens. |
| `data/your_database.dba` | Usually no after testing | Commit only if intentionally reset to an empty sample. |

Use environment variables, DSNs, or deployment secrets for external database credentials.

## 7. Commit changes

Check status:

```bash
git status --short
git diff --check
```

Stage relevant files:

```bash
git add path/to/file1 path/to/file2
```

Commit:

```bash
git commit -m "Update API-POP documentation for v2.0"
```

Push:

```bash
git push
```

## 8. Pull request review

Before merging:

- Review code changes.
- Review configuration changes.
- Check no credentials or local data were committed.
- Confirm documentation matches the current app behavior.
- Confirm release notes mention user-facing changes.

## 9. Deploy

Only deploy after team review.

Typical shinyapps.io deployment:

```r
rsconnect::deployApp()
```

Confirm the deployment profile and data source before publishing.

## 10. Suggested v2.0 release tag

Use a clear version tag:

```bash
git tag v2.0.0
git push origin v2.0.0
```

For GitHub Releases, use a title such as:

```text
API-POP v2.0.0
```
