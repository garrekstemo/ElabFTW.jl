# Items and Linking

By the end of this tutorial you will have created a catalog of lab resources as eLabFTW *items*, attached characterization files and preparation history to them, and connected them to experiments and to each other with cross-entity links.

Experiments describe *what you did*. Items describe *what you used* — samples, instruments, reagents, substrates, or any other long-lived resource that participates in more than one experiment. Modeling these separately keeps an experiment record focused on the analysis while the shared resources live in one well-known place.

| Entity | Use for |
|--------|---------|
| Experiment | Analysis runs, measurements, protocols — things that happen once |
| Item | Samples, instruments, reagents, substrates — things that are reused |

## Prerequisites

```julia
using ElabFTW

configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
test_connection()
```

## 1. Discover your items categories

Every eLabFTW item belongs to a category (the "items type") defined by your team. Category IDs are integers that vary from one eLabFTW instance to another, so the first step on a new instance is to list what is available:

```julia
for t in list_items_types()
    println(t["id"], ": ", t["title"])
end
```

Keep a note of the IDs for the categories you will use — for example `5` for "Sample" and `12` for "Instrument". You can also define a category with `create_items_type` if one does not exist yet.

## 2. Create an item

`create_item` takes a title and a category. A body and metadata are optional, but the body is a good place for a short description:

```julia
sample_id = create_item(
    title    = "Sample A",
    category = 5,
    body     = "Prepared April 2026. Stored under nitrogen."
)
```

Add or refine the body later with `update_item`:

```julia
update_item(sample_id; body = "Prepared April 2026. Stored under nitrogen. Re-measured on day 14.")
```

Tags work the same as on experiments. Use them to record material class, project, or any other grouping:

```julia
tag_item(sample_id, ["project-alpha", "batch-2026-04"])
```

## 3. Attach characterization files

Upload spectra, images, or any other file that characterizes the resource itself, distinct from the experiments that use it:

```julia
upload_to_item(sample_id, "data/characterization/sample_a.csv";
    comment = "Reference characterization")
upload_to_item(sample_id, "figures/sample_a_photo.png";
    comment = "Photograph after prep")
```

Listing and deleting uploads mirrors the experiment API:

```julia
for u in list_item_uploads(sample_id)
    println(u["id"], "  ", u["real_name"])
end
```

## 4. Record preparation history as steps

Sample preparation history is a natural fit for item steps. Each step represents one stage of preparation; mark them finished as you complete them:

```julia
p1 = add_item_step(sample_id, "Synthesize precursor")
p2 = add_item_step(sample_id, "Transfer to substrate")
p3 = add_item_step(sample_id, "Anneal at 400 °C for 2 h")

finish_item_step(sample_id, p1)
finish_item_step(sample_id, p2)
```

Review the current state with `list_item_steps`:

```julia
for step in list_item_steps(sample_id)
    status = get(step, "finished", false) ? "done" : "todo"
    println("[", status, "] ", step["body"])
end
```

## 5. Register other resources

Use the same pattern for instruments, reagents, and substrates. The category ID is different, but every other call is identical:

```julia
instrument_id = create_item(title="Spectrometer #1", category=12)
tag_item(instrument_id, ["instrument", "spectrometer"])

reagent_id = create_item(title="Solvent lot 2026-03", category=8)
tag_item(reagent_id, ["reagent"])
```

## 6. Link items to experiments

Cross-entity links are how you connect a measurement or analysis to the resources it used. Links are visible in the eLabFTW UI on both sides.

```julia
analysis_id = create_experiment(title="Measurement on Sample A")

link_experiment_to_item(analysis_id, sample_id)
link_experiment_to_item(analysis_id, instrument_id)
link_experiment_to_item(analysis_id, reagent_id)
```

Query the links from either direction:

```julia
# What resources did this experiment use?
for l in list_experiment_item_links(analysis_id)
    println(l["itemid"], "  ", l["title"])
end

# Which experiments used this sample?
for l in list_item_experiment_links(sample_id)
    println(l["itemid"], "  ", l["title"])
end
```

Remove a link with `unlink_experiment_from_item(analysis_id, sample_id)`.

## 7. Link items to each other

Items can also be linked to other items. This is useful for relationships that exist independently of any single experiment — a sample mounted on a particular substrate, a reagent derived from a parent lot, or an instrument paired with a calibration standard.

```julia
substrate_id = create_item(title="Substrate wafer B-14", category=7)
link_items(sample_id, substrate_id)

# Which items are linked from this one?
for l in list_item_links(sample_id)
    println(l["itemid"], "  ", l["title"])
end
```

## 8. Search and browse

Find items later by tag or free-text query:

```julia
samples = search_items(tags=["project-alpha"])
print_items(samples)

instruments = search_items(query="spectrometer")
print_items(instruments)
```

`search_items` filters items that have *all* specified tags. Combine `tags` and `query` to narrow further:

```julia
recent = search_items(tags=["project-alpha"], query="sample a", limit=10)
```

`print_items` gives a compact table view that works well in the REPL. For a single record, call `get_item(id)` and read fields directly from the returned `Dict`.

## See also

- [Items](../reference/items.md) — full reference for item CRUD, tags, uploads, and steps
- [Links](@ref) — experiment-to-item, item-to-experiment, and item-to-item linking
- [Templates](@ref) — `list_items_types`, `create_items_type`, and experiment templates
- [Iterative Experiment](@ref) — build up the experiment side of the record
- [Printing](@ref) — `print_items`, `print_experiments`, `print_tags` for quick tabular views
