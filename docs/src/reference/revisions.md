# Revisions

Every time an experiment, item, or experiment template body changes,
eLabFTW may snapshot the prior content as a revision. Whether a given
edit produces a revision depends on the instance's
`max_revisions`, `min_days_revisions`, and `min_delta_revisions`
configuration — not every edit creates one.

Revisions are **read-only** from the API: there's no `create_revision`
(the server manages creation) and no `delete_revision` (the spec has no
DELETE verb). You can list them, fetch an individual revision's body,
and roll the entity back.

## Functions

```@docs
list_revisions
get_revision
restore_revision
```

## Notes

- `list_revisions` returns summary rows only (no `body`). Call
  `get_revision` for the full content.
- `restore_revision` overwrites the active body and does **not** produce
  a new revision of the state being replaced. Restoring is a one-way
  jump — if you need to undo it, restore again from the revision you
  want.
- Supported entity types: `:experiments`, `:items`, `:experiments_templates`.
