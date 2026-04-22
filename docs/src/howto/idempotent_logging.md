# Idempotent Logging

This guide shows how to keep an analysis script from creating a new eLabFTW experiment every time you re-run it.

## The Problem

A typical analysis script loads data, fits a model, and posts results to eLabFTW. If you use `create_experiment` directly, every re-run creates a brand-new experiment:

```julia
# Don't do this in a script you will re-run
id = create_experiment(title="FTIR: CN stretch fit", body=results_md)
```

After ten runs you have ten experiments with the same title and only the last one reflects the current analysis. You want one experiment per script that *updates in place*.

## The Idempotent Entry Point

`log_to_elab` solves this. On the first call it creates an experiment and writes a `.elab_id` file next to the running script. On subsequent calls it reads `.elab_id`, finds the existing experiment, and updates it instead of creating a new one.

```julia
using ElabFTW

id = log_to_elab(
    title       = "FTIR: CN stretch fit",
    body        = results_md,
    tags        = ["ftir", "nh4scn", "preliminary"],
    attachments = ["figures/fit.png", "figures/residuals.png"],
)
```

Run the script ten times — you still have one experiment, and its body, tags, and uploads reflect the most recent run. Attachments are matched by filename and replaced, so regenerated figures overwrite their predecessors cleanly.

`log_to_elab` detects re-runs by matching the `title` against the `.elab_id` file. Changing the title mid-project will create a second experiment; pick a title you're happy with before the first run.

## Forcing a Fresh Entry

To split off a new experiment — for example, when you start a follow-up analysis in the same directory — either:

1. **Delete `.elab_id`** next to the script. The next run creates a new experiment.
2. **Move the script** to a different directory. `log_to_elab` writes `.elab_id` next to `Base.PROGRAM_FILE`, so a different location means a different `.elab_id`.

Deleting or moving the file is harmless: the original experiment is untouched on the server.

## When to Use Lower-Level Functions

`log_to_elab` assumes one analysis script maps to one experiment. That covers most day-to-day analysis work — fit a peak, log results, move on.

Reach for `create_experiment` and `update_experiment` when a single experiment is built up from multiple sources: several measurements posted incrementally, an interactive notebook session, or a workflow that adds steps and links over time. See the [Iterative Experiment](@ref) tutorial for that pattern.

| Situation                                                    | Use                                       |
| ------------------------------------------------------------ | ----------------------------------------- |
| One script → one experiment, re-run frequently               | `log_to_elab`                             |
| Experiment assembled from multiple scripts or sessions       | `create_experiment` + `update_experiment` |
| Logging only when analysis is final (no updates needed)      | `create_experiment`                       |

## Auto-Tagging from Sample Metadata

If your data loader attaches sample metadata to the spectrum (solute, solvent, material, concentration), `tags_from_sample` extracts those values as tags:

```julia
sample = Dict(
    "solute"        => "NH4SCN",
    "solvent"       => "DMF",
    "concentration" => "1.0M",
)

tags = tags_from_sample(sample)
# => ["NH4SCN", "DMF", "1.0M"]

log_to_elab(title="FTIR: CN stretch fit", body=results_md, tags=tags)
```

Internal fields (`_id`, `path`, `date`, `pathlength`) are skipped by default. Pass `include=[:solute, :solvent]` to restrict to specific fields or `exclude=[...]` to extend the skip list.

## See Also

- [Provenance](@ref) — `log_to_elab` and `tags_from_sample` reference
- [Iterative Experiment](@ref) — when to build up an experiment across multiple calls
