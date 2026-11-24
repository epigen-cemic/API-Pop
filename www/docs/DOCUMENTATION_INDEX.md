# API-POP: Documentation library

**Documentation revision:** 23 November 2026  
**Edition:** API-POP v2.x; documentation describes the current supported features and source modules.

| Audience | Start here | Scope |
|---|---|---|
| Users | [User Guide (Markdown)](USER_GUIDE.md) / `API-Pop_User-Guide.docx` | Upload, filter, inspect results and download CSV. |
| Institution / country administrators | [Institutional Setup Guide](INSTITUTIONAL_SETUP_GUIDE.md) / `API-Pop_Institutional_Setup_Guide.docx` | Database profile, configuration, country GeoPackages, population joins, hosting. |
| Developers | [Developer Guide](DEVELOPER_GUIDE.md) / `API-Pop_Technical_Documentation.docx` | Modules, data flows, function map, version handling and tests. |
| Data custodians / integrators | [Reports Dictionary](Data_Dictionary_API-Pop.md) | Input/source records and field assumptions. |
| Data custodians / integrators | [Filtered Cases CSV Dictionary](Data_Dictionary_API-Pop_cases.md) | Case CSV exported from current query. |
| Data custodians / integrators | [Weekly Summary Dictionary](Data_Dictionary_API-Pop_weekly_pop.md) | Weekly counts and optional population. |

**Publication note:** these guides describe current code, not a future universal API. Features found in older documents but not in the source are not represented as available. Metadata naming currently differs (`CITATION.cff` software version `2.0.1` versus some older `v2.0` labels); decide a release version before publication. Roxygen2 blocks in `R/` are the function-level companion reference.

The accompanying Word guides follow the Analysis for Action branding and editorial style guide. Documentation is written in British English. An institution distributing these guides externally should check local branding and funder acknowledgements before publication.
