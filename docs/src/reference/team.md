# Team

Team-scoped tag, category, and status management.

## Tags

```@docs
list_team_tags
rename_team_tag
delete_team_tag
```

## Categories

Categories are lightweight `(title, color, is_default)` labels that
experiments and items reference via their `category` field. `entity_type`
is `:experiments` or `:items`.

```@docs
list_experiments_categories
list_items_categories
create_category
get_category
update_category
delete_category
```

## Statuses

Status labels for experiments and items — same shape as categories, with
separate API namespaces. `entity_type` is `:experiments` or `:items`.

```@docs
list_status
create_status
get_status
update_status
delete_status
```
