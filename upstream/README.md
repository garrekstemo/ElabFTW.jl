# `upstream/` — eLabFTW API spec tracking

This directory holds a **snapshot of the official eLabFTW API v2 OpenAPI spec**,
used to detect when the upstream API changes so this Julia client can be kept in
sync.

| File | Purpose |
|------|---------|
| `openapi.yaml` | Snapshot of `apidoc/v2/openapi.yaml` from the eLabFTW release named in `.spec-version`. The baseline the monthly check diffs against. |
| `.spec-version` | The eLabFTW release tag the snapshot was taken from (e.g. `5.5.12`). |

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
