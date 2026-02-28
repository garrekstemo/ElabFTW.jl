# ElabFTW.jl — Project Instructions

Standalone Julia client for [eLabFTW](https://www.elabftw.net/) API v2. Pure HTTP/JSON — no spectroscopy dependencies.

## eLabFTW API Architecture

eLabFTW has two separate concepts for resources (items) that are easily confused:

- **`resources_categories`** (at `/teams/{id}/resources_categories/`) — lightweight name+color labels. This is what items reference via their `category` field. Managed by team admins. CRUD uses `statuslike` schema: `title`, `color`, `is_default`.
- **`items_types`** (at `/items_types/`) — rich templates with body, metadata, and `extra_fields` that define the default structure for new items. These are like experiment templates but for resources.

Both are needed: categories for labeling items, templates for extra_fields schemas. The same pattern applies to experiments: `experiments_categories` (statuslike labels) vs `experiments_templates` (rich templates).

**Key gotcha**: Creating an `items_type` via the API does NOT create a `resources_category`. Items assigned to an `items_type` ID will display the `resources_category` at that same numeric ID (if one exists), not the `items_type` title. Always create categories via the team endpoint first.

## QPS Lab Configuration

- **Team ID**: 26 (Quantum Photo-Science Laboratory)
- **Resource categories**: Sample (#107, green), Instrument (#104, steel blue), Procedure (#103, amber)
- **Resource templates**: Sample (#109), Instrument (#110), Procedure (#111) — with extra_fields for structured metadata
- **Experiment categories**: PL, UV-Vis, FTIR, Raman, TA, XRD, General
- **Setup script**: `scripts/setup-resources.jl` — creates categories, templates, and migrates items
- **Tag seed script**: lives in QPSLab repo at `scripts/seed-elab-tags.sh`
