# ElabFTW.jl

```@docs
ElabFTW
```

## Quick Start

### Configure

```julia
using ElabFTW

configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
test_connection()
```

Or set `ELABFTW_URL` and `ELABFTW_API_KEY` environment variables for
automatic configuration on package load.

### Create and Track an Experiment

```julia
id = create_experiment(title="FTIR analysis of sample A")
s1 = add_step(id, "Load raw spectra")
s2 = add_step(id, "Baseline correct and normalize")
s3 = add_step(id, "Fit peaks with Voigt model")

finish_step(id, s1)
upload_to_experiment(id, "spectra.csv")
tag_experiment(id, ["ftir", "sample-a"])
```

### Search and Browse

```julia
exps = search_experiments(tags=["ftir"])
print_experiments(exps)

items = search_items(query="MoS2")
print_items(items)
```

### Link Entities

```julia
sample_id = create_item(title="MoS2 sample A", category=5)
link_experiment_to_item(id, sample_id)
link_experiments(id, previous_experiment_id)
```

### Idempotent Logging

```julia
log_to_elab(
    title = "PL fit results",
    body = "<h1>Results</h1><p>Peak at 632 nm</p>",
    tags = ["pl", "sample-a"],
    directory = "results/"
)
```

`log_to_elab` creates a `.elab_id` file in the directory to track the experiment ID.
Subsequent calls update the existing experiment instead of creating duplicates.

## Caching

Downloaded files are cached locally in `~/.cache/elabftw/`.
The cache is checked before making API requests.
Use [`clear_elabftw_cache`](@ref) to clear it and [`elabftw_cache_info`](@ref) to check usage.
