# API-POP | Product Overview

API-POP supports case-record filtering, file-upload review and mapping, and two CSV downloads: filtered case results and weekly geographic counts with optional population. It is part of the Analysis for Action RAP tool family.

The current application belongs to the v2.x release line. Its software version is declared as `2.0.1` in `CITATION.cff`; this documentation revision is dated 2026-11-23. This document is an overview, not an implementation specification.

For practical instructions, use the [User Guide](USER_GUIDE.md). For institutional deployment, database and country configuration, use the [Institutional Setup Guide](INSTITUTIONAL_SETUP_GUIDE.md). For function locations, source architecture, version management and tests, use the [Developer Guide](DEVELOPER_GUIDE.md). All publications are indexed in [Documentation Library](DOCUMENTATION_INDEX.md).

**Current constraints:** the app writes staged uploads to its configured table; startup may add normalization columns. ODBC connection helpers do not imply universal SQL compatibility. Automatic storage failover and arbitrary source-schema adapters are not implemented in this release.
