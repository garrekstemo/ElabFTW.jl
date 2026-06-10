# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-10

First release.

### Added

- Hand-written Julia client for the [eLabFTW](https://www.elabftw.net/) API
  v2: experiments, items (resources), templates, tags, uploads, steps,
  comments, links, compounds, scheduler events, storage units and containers,
  revisions, team categories/statuses, favorite tags, import/export, and
  instance info.
- Typed error hierarchy (`ElabFTWError` with `AuthError`, `PermissionError`,
  `NotFoundError`, `RateLimitError`, `ClientError`, `ServerError`,
  `NetworkError`, `ParseError`, `NotConfiguredError`) plus centralized retry
  with exponential backoff that honors `Retry-After` on 429.
- Provenance logging: `log_to_elab` idempotently creates or updates an
  experiment from an analysis script, tracking the entry via a `.elab_id`
  marker written next to the running script; `tags_from_sample` extracts tags
  from sample metadata.
- Batch operations with dry-run safety: `delete_experiments`,
  `tag_experiments`, `update_experiments`, and their items counterparts.
- Local file cache for downloaded attachments (`download_item_upload`,
  `download_experiment_upload`, `clear_elabftw_cache`, `elabftw_cache_info`).
- Per-entity export in all spec formats (`create_export`, `download_export`).
- Pretty-printers for terminal browsing: `print_experiments`, `print_items`,
  `print_tags`.
- Configuration via `configure_elabftw` or the `ELABFTW_URL` /
  `ELABFTW_API_KEY` environment variables.
- Offline stateful mock-server test suite covering every implemented endpoint
  group, with controlled failure injection for the retry/backoff and
  error-mapping paths, plus an opt-in live-instance test
  (`test/test_live.jl`).
- Documenter docs site (tutorials, how-to guides, full reference), Aqua QA in
  CI, and a monthly CI drift check against the vendored upstream OpenAPI spec
  (`upstream/openapi.yaml`, eLabFTW 5.5.12).

[0.1.0]: https://github.com/garrekstemo/ElabFTW.jl/releases/tag/v0.1.0
