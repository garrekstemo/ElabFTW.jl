# Iterative Experiment

By the end of this tutorial you will have built up a single eLabFTW experiment across multiple runs of an analysis script, uploading figures and raw data as they are produced, tagging each contribution, and posting a summary body at the end.

This pattern is useful whenever a single logical experiment is analyzed in pieces — for example, when a batch of measurement files is processed one at a time, or when analysis proceeds over several working sessions. Instead of creating a new eLabFTW entry every time, you hold onto one experiment ID and keep appending to it.

## Prerequisites

```julia
using ElabFTW

configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
test_connection()
```

If `ELABFTW_URL` and `ELABFTW_API_KEY` are already set in your environment, the package auto-configures on load.

## 1. Create the experiment once

The first time you start an analysis, create a fresh experiment and record the ID somewhere your script can read it back. A common pattern is to stash the ID in a local text file or pass it in as a script argument.

```julia
analysis_id = create_experiment(
    title = "Batch analysis — project alpha",
    body  = "Tracking results from the April measurement campaign."
)

open("analysis_id.txt", "w") do io
    println(io, analysis_id)
end
```

`create_experiment` returns an `Int`. On a later run, read that same ID back:

```julia
analysis_id = parse(Int, strip(read("analysis_id.txt", String)))
```

## 2. Outline the procedure with steps

Steps are short checklist items attached to an experiment. They are useful for documenting the procedure and tracking progress when the analysis takes several sessions to complete.

```julia
s1 = add_step(analysis_id, "Load and inspect raw data")
s2 = add_step(analysis_id, "Fit each measurement")
s3 = add_step(analysis_id, "Aggregate results and write summary")
```

`add_step` returns the step ID. Mark a step as finished whenever the corresponding block of work is done:

```julia
finish_step(analysis_id, s1)
```

Retrieve the current checklist at any time:

```julia
for step in list_steps(analysis_id)
    status = get(step, "finished", false) ? "done" : "todo"
    println("[", status, "] ", step["body"])
end
```

## 3. Loop over measurements, upload as you go

The body of a typical iterative analysis processes one file at a time. For each file, save an output artifact (figure, fit log, exported CSV) and push it to the experiment.

```julia
measurement_files = readdir("data/"; join=true)
results = Dict{String, Any}()

for (i, path) in enumerate(measurement_files)
    # Run whatever analysis this project needs
    result = run_analysis(path)
    results[basename(path)] = result

    # Save a figure locally
    figpath = "figures/run_$(i).png"
    save_figure(figpath, result)

    # Attach it to the experiment with a short note
    upload_to_experiment(
        analysis_id,
        figpath;
        comment = "Run $i — $(basename(path))"
    )

    # Tag this contribution so it is easy to find later
    tag_experiment(analysis_id, "run_$i")
end

finish_step(analysis_id, s2)
```

`upload_to_experiment` returns the ID of the upload, which you can keep if you later want to delete or replace that specific attachment. You can also upload raw data files alongside the figures — anything local to your machine works.

```julia
upload_to_experiment(analysis_id, "data/export/summary.csv";
    comment = "Aggregated results table")
```

## 4. Tag for searchability

Tags make an experiment findable from the eLabFTW UI and from `search_experiments`. Apply project-level tags once, near the end of the script:

```julia
tag_experiment(analysis_id, ["project-alpha", "batch-analysis", "2026"])
```

`tag_experiment` accepts a single tag or a `Vector{String}`. Re-applying an existing tag is a no-op.

## 5. Post a summary in the body

The experiment body is the narrative record of what happened. Build it up as a string once all measurements have been processed, then post it with `update_experiment`:

```julia
summary = """
# Summary

Processed $(length(measurement_files)) measurements from the April campaign.

| File | Result |
|------|--------|
""" * join(["| $k | $(v.headline) |" for (k, v) in results], "\n")

update_experiment(analysis_id; body = summary)
finish_step(analysis_id, s3)
```

`update_experiment` accepts any combination of `title`, `body`, and `metadata`. Passing `body` replaces the current body — if you want to append, fetch the current body first:

```julia
current = get_experiment(analysis_id)["body"]
update_experiment(analysis_id; body = current * "\n\n" * summary)
```

## 6. Check the result

List the uploads and tags you just attached:

```julia
for u in list_experiment_uploads(analysis_id)
    println(u["id"], "  ", u["real_name"], "  ", u["comment"])
end

for t in list_experiment_tags(analysis_id)
    println(t["tag_id"], ": ", t["tag"])
end
```

Or pull up the experiment record in one go:

```julia
exp = get_experiment(analysis_id)
exp["title"]
exp["body"]
```

## See also

- [Experiments](../reference/experiments.md) — full reference for `create_experiment`, `update_experiment`, `upload_to_experiment`, `add_step`, `finish_step`, and related calls
- [Items and Linking](items_and_linking.md) — connect this experiment to the samples, instruments, and other resources it depended on
- [Printing](@ref) — `print_experiments` for a quick tabular view of search results
- [Batch Operations](@ref) — `tag_experiments` and `update_experiments` for applying the same change across many entries
