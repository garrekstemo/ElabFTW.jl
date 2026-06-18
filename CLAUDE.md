# ElabFTW.jl — Project Instructions

Standalone Julia client for the [eLabFTW](https://www.elabftw.net/) API v2.

## eLabFTW API Architecture

eLabFTW has two separate, easily-confused concepts for resources (items):

- **`resources_categories`** (at `/teams/{id}/resources_categories/`) — lightweight name+color labels. This is what items reference via their `category` field. CRUD uses the `statuslike` schema: `title`, `color`, `is_default`.
- **`items_types`** (at `/items_types/`) — rich templates with body, metadata, and `extra_fields` defining the default structure for new items.

Both are needed: categories for labeling items, templates for extra_fields schemas. Experiments mirror this split: `experiments_categories` vs `experiments_templates`.

**Key gotcha**: Creating an `items_type` via the API does NOT create a `resources_category`. Items assigned to an `items_type` ID display the `resources_category` at that same numeric ID (if one exists), not the `items_type` title. Always create categories via the team endpoint first.

## QPS Lab Configuration

- **Team ID**: 26 (Quantum Photo-Science Laboratory)
- **Resource categories**: Sample (#107, green), Instrument (#104, steel blue), Procedure (#103, amber)
- **Resource templates**: Sample (#109), Instrument (#110), Procedure (#111) — carry extra_fields for structured metadata
- **Experiment categories**: PL, UV-Vis, FTIR, Raman, TA, XRD, General
- **Setup script**: `scripts/setup-resources.jl` — creates categories, templates, and migrates items
- **Tag seed script**: sibling QPSLab repo at `scripts/seed-elab-tags.sh`
