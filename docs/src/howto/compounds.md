# Compounds and chemical inventory

This guide shows how to pull a compound from PubChem, link it to an experiment, and track a physical stock of it in a storage unit. The realistic workflow at the end walks through ammonium thiocyanate from PubChem import to FTIR experiment to freezer drawer.

## Importing from PubChem

`import_compound` asks the eLabFTW server to fetch a compound record from PubChem by CAS number or PubChem CID. Pass exactly one:

```julia
using ElabFTW

nh4scn = import_compound(cas="1762-95-4")
caffeine = import_compound(cas="58-08-2")
aspirin  = import_compound(cid=2244)
```

The server returns 201 with the compound ID whether it created a new row or found an existing match on CAS/CID — `import_compound` is effectively idempotent, so it is safe to call in a script that runs every time you set up a new experiment.

Inspect the record you just imported:

```julia
c = get_compound(nh4scn)
c["name"]                # "Ammonium thiocyanate"
c["molecular_formula"]   # "CH4N2S"
c["cas_number"]          # "1762-95-4"
c["pubchem_cid"]         # 15666
```

When PubChem does not have the compound — or you are cataloguing something in-house — build it yourself with `create_compound`:

```julia
id = create_compound(
    name = "Custom TMDC precursor mixture",
    smiles = "CC(=O)O.[Mo].[S]",
    molecular_formula = "C2H4MoO2S",
)
```

## Linking a Compound to an Experiment

`link_compound` attaches a compound to an experiment or item. The first argument is the entity type (`:experiments` or `:items`):

```julia
exp_id = create_experiment(title="FTIR: NH4SCN in DMF, CN stretch")
link_compound(:experiments, exp_id, nh4scn)
```

Verify the link with `list_compound_links`:

```julia
for c in list_compound_links(:experiments, exp_id)
    println(c["name"], "  (", c["cas_number"], ")")
end
# Ammonium thiocyanate  (1762-95-4)
```

The same pattern binds compounds to sample items:

```julia
sample_id = create_item(title="NH4SCN 1.0 M in DMF (stock)", category=107)
link_compound(:items, sample_id, nh4scn)
```

## Updating Hazard Flags

`update_compound` accepts any field the eLabFTW API recognizes on `PATCH /compounds/{id}`. Hazard flags are `0` or `1` integers:

```julia
update_compound(nh4scn;
    is_toxic = 1,
    is_hazardous2health = 1,
    is_hazardous2env = 1,
)
```

The open `kwargs...` interface means you can set any combination in a single call. Common fields:

| Field                         | Purpose                              |
| ----------------------------- | ------------------------------------ |
| `name`                        | Display name                         |
| `cas_number`, `pubchem_cid`   | External identifiers                 |
| `smiles`, `inchi`, `inchi_key`| Structure encodings                  |
| `is_corrosive`, `is_flammable`| Hazard flags (0/1)                   |
| `is_toxic`, `is_explosive`    | Hazard flags (0/1)                   |
| `is_oxidising`, `is_radioactive` | Hazard flags (0/1)               |
| `is_hazardous2env`, `is_hazardous2health` | Hazard flags (0/1)       |

## Storing a Physical Sample

Compounds describe the chemistry; items describe the physical stock. A single compound record can back many item rows — one per bottle, vial, or batch — each with its own location and quantity.

The storage API tracks where an item sits. Build the location once:

```julia
freezer = create_storage_unit(name="Freezer A")
drawer2 = create_storage_unit(name="Drawer 2", parent_id=freezer)
```

Then attach the sample item to the drawer with a quantity. `create_container` returns the container row ID:

```julia
container_id = create_container(
    :items, sample_id;
    storage_id = drawer2,
    qty_stored = 25,
    qty_unit = "g",
)
```

Valid units are `"bar"`, `"•"`, `"m"`, `"μL"`, `"mL"`, `"L"`, `"μg"`, `"mg"`, `"g"`, `"kg"`. Anything else is truncated to 10 characters server-side, so stick to the enum.

List what is where:

```julia
for row in list_containers(:items, sample_id)
    println(row["full_path"], ": ", row["qty_stored"], " ", row["qty_unit"])
end
# Freezer A / Drawer 2: 25 g
```

When you use some of the stock, adjust the quantity:

```julia
update_container(:items, sample_id, container_id; qty_stored=18)
```

## End-to-End: NH4SCN for an FTIR Experiment

Here is the whole flow compressed into one script:

```julia
using ElabFTW

# 1. Compound record (from PubChem, idempotent)
nh4scn = import_compound(cas="1762-95-4")
update_compound(nh4scn; is_toxic=1, is_hazardous2env=1)

# 2. Physical stock as an item (category 107 = Sample in QPS Lab)
sample_id = create_item(
    title = "NH4SCN solid (Aldrich, >99%, lot 2024-07)",
    category = 107,
)
link_compound(:items, sample_id, nh4scn)
tag_item(sample_id, ["nh4scn", "sample"])

# 3. Tell the notebook where it lives
freezer = create_storage_unit(name="Freezer A")
drawer2 = create_storage_unit(name="Drawer 2", parent_id=freezer)
create_container(:items, sample_id;
    storage_id=drawer2, qty_stored=25, qty_unit="g")

# 4. FTIR experiment, linked to both compound and sample
exp_id = create_experiment(title="FTIR: NH4SCN in DMF, CN stretch")
link_compound(:experiments, exp_id, nh4scn)
link_experiment_to_item(exp_id, sample_id)
tag_experiment(exp_id, ["ftir", "nh4scn"])
```

Rerunning the script is safe: `import_compound` returns the same ID for an existing CAS, and tagging an entity that is already tagged is a server-side no-op. Only the `create_item`, `create_storage_unit`, `create_container`, and `create_experiment` calls are non-idempotent — guard those with `search_items`, `list_storage_units`, or the [Idempotent Logging](idempotent_logging.md) pattern if you re-run the same setup script often.

## See Also

- [Compounds](../reference/compounds.md) — `import_compound`, `create_compound`, `update_compound`, `link_compound`, `list_compound_links`
- [Storage](../reference/storage.md) — `create_storage_unit`, `create_container`, `update_container`, `list_containers`
- [Items](../reference/items.md) — `create_item`, `tag_item`
- [Experiments](../reference/experiments.md) — `create_experiment`, `link_experiment_to_item`
