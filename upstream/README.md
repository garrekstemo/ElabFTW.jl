# `upstream/` — eLabFTW API spec tracking

This directory holds a **snapshot of the official eLabFTW API v2 OpenAPI spec**,
used to detect when the upstream API changes so this Julia client can be kept in
sync.

| File | Purpose |
|------|---------|
| `openapi.yaml` | Snapshot of `apidoc/v2/openapi.yaml` from the eLabFTW release named in `.spec-version`. The baseline the monthly check diffs against. |
| `.spec-version` | The eLabFTW release tag the snapshot was taken from (e.g. `5.5.12`). |

## Provenance and licensing

`openapi.yaml` is copied verbatim from the upstream eLabFTW repository:

- **Source repository:** <https://github.com/elabftw/elabftw>
- **Path in source:** `apidoc/v2/openapi.yaml`
- **Fetched from release:** the tag recorded in [`.spec-version`](.spec-version)
  (currently eLabFTW `5.5.12`)
- **License:** [GNU AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html), the
  license of the eLabFTW project — **not** the MIT license that covers the
  Julia code in this package.

The spec file is included as **mere aggregation**: it is reference data used
only by the CI drift-detection workflow described below. It is not compiled
into, imported by, or otherwise linked with the ElabFTW.jl package code, so
ElabFTW.jl itself remains MIT-licensed. If you redistribute `openapi.yaml`
separately, the AGPL-3.0 terms apply to it.

## How the check works

`.github/workflows/check-elab-api.yml` runs on the 1st of each month (and can be
run manually via *Actions → Check eLabFTW API → Run workflow*). Each run:

1. Resolves the latest **stable** eLabFTW release.
2. Downloads that release's `apidoc/v2/openapi.yaml`.
3. Diffs it against `openapi.yaml` here.
4. If they differ — and no open issue labelled `upstream-api` already exists — it
   files one issue containing the unified diff and a client-update checklist.

The check never writes to the repo, so branch protection and Actions PR policy
don't get in the way.

## Resolving an `upstream-api` issue

Do everything in **one PR**:

- Update the affected functions in `src/` (and tests/docs).
- **Bump the snapshot**: replace `openapi.yaml` with the new release's spec and
  set `.spec-version` to the new tag.

The snapshot bump is what stops the check from re-firing. To refresh the snapshot
manually:

```sh
tag=$(gh api repos/elabftw/elabftw/releases/latest --jq .tag_name)
curl -fsSL "https://raw.githubusercontent.com/elabftw/elabftw/refs/tags/$tag/apidoc/v2/openapi.yaml" -o upstream/openapi.yaml
printf '%s\n' "$tag" > upstream/.spec-version
```
