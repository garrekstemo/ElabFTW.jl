# ElabFTW.jl

[![CI](https://github.com/garrekstemo/ElabFTW.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/garrekstemo/ElabFTW.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/garrekstemo/ElabFTW.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/garrekstemo/ElabFTW.jl)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://garrekstemo.github.io/ElabFTW.jl/dev/)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A Julia client for the [eLabFTW](https://www.elabftw.net/) API v2.

## Installation

```julia
using Pkg
Pkg.add("ElabFTW")
```

To track the development version instead of the latest release:

```julia
Pkg.add(url="https://github.com/garrekstemo/ElabFTW.jl")
```

Requires Julia 1.10 or later.

## Quick Start

```julia
using ElabFTW

configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
test_connection()
```

Or set `ELABFTW_URL` and `ELABFTW_API_KEY` environment variables for automatic configuration on package load.

## Provenance: Log Analysis Results Idempotently

`log_to_elab` is the workflow this package was built around: run an analysis
script, push the results (body, plots, tags, metadata) to eLabFTW, re-run the
script after fixing something — and update the *same* experiment instead of
creating a duplicate.

```julia
using ElabFTW

configure_elabftw(url = "https://your-instance.elabftw.net",
                  api_key = ENV["ELABFTW_API_KEY"])

# ... fit your data, save fit_results.csv and fit_plot.png ...

log_to_elab(
    title = "PL fit results",
    body = "<h1>Results</h1><p>Peak at 632 nm</p>",
    content_type = 1,                       # 1 = HTML; default 2 = Markdown
    tags = ["pl", "sample-a"],
    attachments = ["fit_results.csv", "fit_plot.png"],
)
```

**How idempotency works:** the first run creates the experiment and writes a
`.elab_id` marker file *next to the running script* (the file named by
`Base.PROGRAM_FILE`). Subsequent runs of the same script with the same `title`
find the marker and update the existing experiment — body and metadata are
replaced, tags are reset to the ones you pass, and attachments with matching
filenames are replaced.

> [!WARNING]
> **REPL caveat:** idempotency tracking needs a script file. In the REPL (or a
> notebook) `Base.PROGRAM_FILE` is empty, so no `.elab_id` marker can be
> written and **every call creates a new experiment**. Run your analysis as a
> script (`julia analyze.jl`) to get idempotent updates.

`log_to_elab` returns the experiment ID, so you can chain further calls
(`add_step`, `link_experiment_to_item`, ...) onto the same entry. Commit the
`.elab_id` file alongside the script if you want re-runs on other machines to
update the same experiment.

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

## See Also

- [**elabapi-python**](https://github.com/elabftw/elabapi-python) — the official Python client from the eLabFTW team. The reference implementation for the v2 API; this Julia client's surface was derived from the same [OpenAPI spec](https://github.com/elabftw/elabftw/blob/master/apidoc/v2/openapi.yaml).
