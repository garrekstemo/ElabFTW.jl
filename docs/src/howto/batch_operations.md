# Batch operations

This guide shows how to delete, tag, and rewrite many experiments or items in one call. Batch operations all accept a `query` and/or `tags` filter — at least one must be given — and return the vector of entity IDs that were touched.

## Preview Before Deleting

`delete_experiments` and `delete_items` default to `dry_run=true`. The first call prints the matching rows and does nothing to the server:

```julia
using ElabFTW

delete_experiments(tags=["test"])
# Would delete 4 experiment(s):
#   7301: FTIR smoke test
#   7302: Dummy run — delete me
#   7319: throwaway
#   7401: scratch-experiment
#
# Re-run with dry_run=false to delete
```

Run it again with `dry_run=false` once the list looks right:

```julia
delete_experiments(tags=["test"]; dry_run=false)
```

The same pattern applies to items:

```julia
delete_items(query="scratch"; dry_run=false)
```

Both functions combine filters with AND — `tags=["test", "2024"]` matches only entries that carry both tags. Pass a `query` string for full-text filtering against title and body.

## Adding a Review Tag Across Many Experiments

`tag_experiments` searches the team and adds a tag to every match. No dry-run — the change is small, reversible (`untag_experiment`), and the function prints the count as it runs:

```julia
# Mark every FTIR experiment tagged 2025 as reviewed
tag_experiments("reviewed"; tags=["ftir", "2025"])
# Adding tag 'reviewed' to 17 experiment(s)...
# Done

# Tag everything mentioning NH4SCN for a follow-up sweep
tag_experiments("follow_up"; query="NH4SCN")
```

`tag_items` is the resource-side equivalent:

```julia
# Flag every MoS2 sample as currently in use
tag_items("in_use"; tags=["mos2"])
```

Both return the list of IDs that were updated. If no entries match, the return is `Int[]` and a "No experiments match the criteria" message goes to stdout — batch calls never throw on empty results, so script them freely.

See [Tagging Conventions](tagging_conventions.md) for guidance on keeping tag names consistent so these searches stay sharp.

## Appending a Footer to All Drafts

`update_experiments` and `update_items` each accept two mutually-recognized body kwargs:

- `new_body=...` — overwrite the existing body.
- `append_body=...` — fetch the current body and append the string.

At least one must be supplied. Appending is usually what you want for retroactive notes:

```julia
update_experiments(
    tags = ["draft"];
    append_body = "\n\n---\nReviewed on 2026-04-01 during Q2 audit."
)
# Updating 23 experiment(s)...
# Done
```

Append is implemented as read-then-write per entity, so it costs two HTTP calls per match — fine for dozens, slow for thousands. Use `new_body` when you want every entry set to the same canned footer (one call per entity).

The same kwargs work on items:

```julia
update_items(
    tags = ["sample", "depleted"];
    append_body = "\n\n*This stock was exhausted and disposed of on 2026-04-10.*"
)
```

## Combining with Search Filters

Batch functions piggyback on the same search backend as [`search_experiments`](@ref) and [`search_items`](@ref). Compose a tag sweep with a text query to narrow the blast radius:

```julia
# Tag only the reviewed FTIR experiments that mention the CN stretch region
tag_experiments("cn_stretch"; tags=["ftir", "reviewed"], query="2050-2200 cm")
```

When you want to see what a filter would hit before running the operation, call `search_experiments` with the same arguments first:

```julia
matches = search_experiments(tags=["draft"], query="FTIR")
println("Would touch $(length(matches)) experiments")
for e in matches
    println("  $(e["id"]): $(e["title"])")
end
```

Then re-issue the same filter to `update_experiments` or `tag_experiments`.

## Failure Modes

Batch operations do not retry or roll back. If one of 30 PATCHes errors out — network drop, permission denied on a single entity — the loop raises on that row and the preceding updates stay applied. Re-running the same call is safe for tag-adds (tagging an already-tagged entity is a no-op at the server) and for `new_body` / `append_body` where the replacement is idempotent; for `append_body`, re-running duplicates the appended text.

A tight rerun strategy for append is to tag first, then filter out what you already touched:

```julia
update_experiments(tags=["draft"]; append_body="\n\n*Reviewed.*")
tag_experiments("reviewed"; tags=["draft"])

# Skip the ones you already reviewed. eLabFTW's `tags` filter is AND-only,
# so exclusion has to happen client-side.
drafts = search_experiments(tags=["draft"])
pending = [e for e in drafts
           if !any(t -> t["tag"] == "reviewed", something(e["tags"], []))]
for e in pending
    update_experiment(e["id"]; body=e["body"] * "\n\n*Reviewed.*")
    tag_experiment(e["id"], "reviewed")
end
```

## See Also

- [Batch Operations](../reference/batch.md) — full signatures for `delete_experiments`, `tag_experiments`, `update_experiments`, `delete_items`, `tag_items`, `update_items`
- [Tagging Conventions](tagging_conventions.md) — how to keep tag filters effective
- [Experiments](../reference/experiments.md) — `search_experiments` for previewing matches
- [Items](../reference/items.md) — `search_items` for previewing matches
