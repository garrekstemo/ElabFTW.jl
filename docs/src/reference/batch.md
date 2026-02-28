# Batch Operations

Operate on multiple experiments or items in a single call.

!!! warning "Destructive operations"
    `delete_experiments` and `delete_items` support a `dry_run=true` parameter
    (default) that previews the operation without executing it.
    Set `dry_run=false` to actually delete.

## Experiments

```@docs
delete_experiments
tag_experiments
update_experiments
```

## Items

```@docs
delete_items
tag_items
update_items
```
