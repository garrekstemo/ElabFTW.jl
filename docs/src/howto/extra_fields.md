# Metadata forms and extra fields

This guide shows how to attach structured metadata to experiments and items, look up what key names are already in use across the team, and bake a default metadata schema into an items type so every new resource starts with the right fields.

## The `extra_fields` Shape

eLabFTW stores structured metadata as a JSON blob on the entity. The canonical shape is an object with a top-level `"extra_fields"` key whose value maps field names to small descriptor objects:

```json
{
  "extra_fields": {
    "concentration": {"type": "number", "value": "1.0", "unit": "M"},
    "solvent":       {"type": "text",   "value": "DMF"},
    "pathlength":    {"type": "number", "value": "50", "unit": "μm"}
  }
}
```

The `type` drives the form widget eLabFTW renders: `"text"`, `"number"`, `"date"`, `"url"`, `"select"`, `"checkbox"`, `"radio"`. `value` is always a string (even for numbers). Optional descriptor keys include `description`, `unit`, `required`, `options` (for select/radio), and `position`.

In Julia this becomes a nested `Dict`:

```julia
using ElabFTW

md = Dict("extra_fields" => Dict(
    "concentration" => Dict("type" => "number", "value" => "1.0", "unit" => "M"),
    "solvent"       => Dict("type" => "text",   "value" => "DMF"),
    "pathlength"    => Dict("type" => "number", "value" => "50", "unit" => "μm"),
))
```

## Creating an Experiment with Metadata

`create_experiment` and `update_experiment` both accept a `metadata::Dict` kwarg — pass the full outer envelope (with the `"extra_fields"` key):

```julia
id = create_experiment(
    title    = "FTIR: NH4SCN in DMF, CN stretch",
    body     = "CN stretch region, 2050–2200 cm⁻¹.",
    category = 3,                # e.g. FTIR category
    metadata = md,
)
```

Update only the metadata later:

```julia
md["extra_fields"]["concentration"]["value"] = "0.5"
update_experiment(id; metadata=md)
```

Reading back returns the parsed JSON:

```julia
e = get_experiment(id)
e["metadata"]
# Dict("extra_fields" => Dict("concentration" => Dict(...), ...))
```

Items take the same `metadata` kwarg on `create_item` / `update_item`:

```julia
sample = create_item(
    title    = "MoS2 sample A",
    category = 107,
    metadata = Dict("extra_fields" => Dict(
        "growth_method" => Dict("type" => "text",   "value" => "CVD"),
        "thickness_nm"  => Dict("type" => "number", "value" => "0.65"),
    )),
)
```

## Finding Existing Field Names

`search_extra_fields_keys` returns every `extra_fields` key in use across the team, sorted by frequency. Use it before inventing a new name to avoid collisions with what your teammates already write:

```julia
for k in search_extra_fields_keys()
    println(rpad(k["extra_fields_key"], 30), k["frequency"])
end
# concentration              47
# solvent                    43
# pathlength                 21
# growth_method              12
# ...
```

Pass `q=...` to narrow to a substring:

```julia
for k in search_extra_fields_keys(q="conc")
    println(k["extra_fields_key"], "  (", k["frequency"], " uses)")
end
# concentration       47
# concentration_m     3
# initial_conc_mg     1
```

The output highlights near-duplicates — here `concentration_m` and `initial_conc_mg` should probably consolidate with the canonical `concentration`. `limit=0` returns the server's default page size; pass `limit=-1` for all keys in one response.

## Building a Template: Items Type with Default Fields

An items type (a.k.a. resource template) defines the default body and metadata for every new item created under it. Create it with `create_items_type` and pass a `metadata` Dict that describes the schema users should start from:

```julia
schema = Dict("extra_fields" => Dict(
    "cas_number" => Dict(
        "type"        => "text",
        "value"       => "",
        "description" => "CAS registry number",
        "position"    => 1,
    ),
    "supplier" => Dict(
        "type"     => "text",
        "value"    => "",
        "position" => 2,
    ),
    "purity" => Dict(
        "type"     => "text",
        "value"    => "",
        "unit"     => "%",
        "position" => 3,
    ),
    "hazard_class" => Dict(
        "type"     => "select",
        "value"    => "",
        "options"  => ["none", "toxic", "flammable", "corrosive", "reactive"],
        "position" => 4,
    ),
))

sample_type = create_items_type(
    title    = "Sample (chemistry)",
    body     = "## Provenance\n\n## Storage\n\n## Notes\n",
    metadata = schema,
)
```

New items created with `create_item(..., category=sample_type)` inherit the schema — users fill in the values per-item and the field names stay consistent across the whole collection.

Update the template with `update_items_type`:

```julia
schema["extra_fields"]["lot_number"] = Dict(
    "type"     => "text",
    "value"    => "",
    "position" => 5,
)
update_items_type(sample_type; metadata=schema)
```

Existing items are *not* rewritten when you edit the template — the template only seeds new entries. Propagate a schema change to historical items with a [batch update](batch_operations.md) that merges new fields into each item's existing metadata.

## Experiments Templates Do Not Accept Metadata

`create_experiment_template` and `update_experiment_template` in this package take `title` and `body` only — the eLabFTW experiments-template endpoint does not document an `extra_fields` schema. If you want a reusable experiment form, put the default `metadata` into a Julia helper and pass it into `create_experiment(..., metadata=...)` directly.

```julia
function ftir_experiment(title; solute, solvent, concentration, pathlength_um)
    md = Dict("extra_fields" => Dict(
        "solute"        => Dict("type" => "text",   "value" => solute),
        "solvent"       => Dict("type" => "text",   "value" => solvent),
        "concentration" => Dict("type" => "number", "value" => string(concentration), "unit" => "M"),
        "pathlength"    => Dict("type" => "number", "value" => string(pathlength_um), "unit" => "μm"),
    ))
    return create_experiment(title=title, category=3, metadata=md)
end

id = ftir_experiment("FTIR: NH4SCN in DMF";
    solute="NH4SCN", solvent="DMF", concentration=1.0, pathlength_um=50)
```

## See Also

- [Templates](../reference/templates.md) — `create_items_type`, `update_items_type`, `create_experiment_template`
- [Utility](../reference/utility.md) — `search_extra_fields_keys`
- [Experiments](../reference/experiments.md) — `create_experiment`, `update_experiment` (metadata kwarg)
- [Items](../reference/items.md) — `create_item`, `update_item` (metadata kwarg)
- [Batch operations](batch_operations.md) — propagate a new schema across existing items
