# Tagging Conventions

This guide shows how to tag experiments and items so they stay findable as the notebook grows.

## Tag Format

Pick one convention and apply it everywhere. The examples below use **lowercase with underscores**:

- Lowercase: `ftir`, not `FTIR` or `FTir`
- Underscores for multi-word tags: `pump_probe`, not `pump-probe` or `pumpProbe`
- No spaces, no punctuation beyond underscores
- Singular nouns: `sample`, not `samples`

Consistency matters more than the specific choice — pick hyphens instead if you prefer, and stick with it.

## Tag Categories

Organize tags into a small number of orthogonal categories so every entry can receive one tag from each that applies.

| Category  | Purpose                            | Examples                                         |
| --------- | ---------------------------------- | ------------------------------------------------ |
| Technique | Measurement or analysis method     | `ftir`, `raman`, `uv_vis`, `pump_probe`          |
| Sample    | Material or system being studied   | `mos2`, `nh4scn`, `mapbi3`, `water`              |
| Team      | Group or collaboration             | `cavity_team`, `tmdc_team`, `external_collab`    |
| Status    | Lifecycle state of the entry       | `preliminary`, `reviewed`, `publication_ready`   |
| Project   | Higher-level research program      | `cavity_lifetime`, `2d_materials`, `thesis_ch3`  |

## Applying Tags Programmatically

Add one or several tags to a single entity:

```julia
using ElabFTW

tag_experiment(42, "ftir")
tag_experiment(42, ["ftir", "nh4scn", "preliminary"])

tag_item(107, ["mos2", "tmdc_team"])
```

List the tags currently on an entity:

```julia
list_experiment_tags(42)
list_item_tags(107)
```

List every tag in use across the team registry:

```julia
list_team_tags()
```

## Batch Tagging for Backfills

`tag_experiments` and `tag_items` search the team for matching entries and tag them in one call. Filter by existing tags, a full-text query, or both:

```julia
# Add "archived" to every experiment already tagged "2024"
tag_experiments("archived"; tags=["2024"])

# Add "reviewed" to every experiment mentioning NH4SCN
tag_experiments("reviewed"; query="NH4SCN")

# Add a status tag to every sample tagged as mos2
tag_items("in_use"; tags=["mos2"])
```

Both functions return the vector of entity IDs that were updated.

## Team-Level Housekeeping

Over time, typos and near-duplicates accumulate in the team registry (`ftir` vs `FTIR` vs `Ftir`). `rename_team_tag` merges a tag into an existing one — renaming to a name that already exists collapses the two. `delete_team_tag` removes a tag from the registry and from every entity that references it.

Both functions take a tag ID, which you get from `list_team_tags`:

```julia
tags = list_team_tags()
for t in tags
    println(t["id"], ": ", t["tag"])
end

# Consolidate "FTIR" into "ftir"
rename_team_tag(42, "ftir")

# Remove an obsolete tag everywhere
delete_team_tag(107)
```

Both operations are admin-only.

## See Also

- [Experiments](@ref) — `tag_experiment`, `list_experiment_tags`
- [Items](@ref) — `tag_item`, `list_item_tags`
- [Team](@ref) — `list_team_tags`, `rename_team_tag`, `delete_team_tag`
- [Batch Operations](@ref) — `tag_experiments`, `tag_items`
