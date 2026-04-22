# ElabFTW.jl

```@docs
ElabFTW
```

A Julia client for the [eLabFTW](https://www.elabftw.net/) electronic lab notebook — full read/write access to experiments, items (resources), uploads, tags, links, comments, templates, scheduler events, and compounds via the v2 API.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/garrekstemo/ElabFTW.jl")
```

## Configure

### Option 1: Environment variables (recommended)

Add these two lines to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
export ELABFTW_URL="https://your-instance.elabftw.net"
export ELABFTW_API_KEY="3-abcdef..."
```

Then restart your terminal or `source` the profile. `ElabFTW.jl` auto-configures from these environment variables when the package loads.

### Option 2: Configure manually in Julia

```julia
using ElabFTW

configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
```

### Get an API key

1. Log in to your eLabFTW instance in a web browser.
2. Go to **Settings** (gear icon, top-right).
3. Scroll to **API Keys** → **Create a new key**.
4. Name it (e.g. `julia-client`), set access to **Read/Write**.
5. Copy the key — it starts with a digit, like `3-abcdef...`.

**Treat the key like a password.** Anyone with it has full access to your account.

### Verify

```julia
julia> elabftw_enabled()
true

julia> test_connection()
# prints server reachability and auth status
```

### Offline mode

Temporarily disable eLabFTW to avoid connection errors during offline work:

```julia
disable_elabftw()   # switch to local-only mode
enable_elabftw()    # re-enable
```

## Quick Start

### Create and track an experiment

```julia
id = create_experiment(title="FTIR analysis of sample A")
s1 = add_step(id, "Load raw spectra")
s2 = add_step(id, "Baseline correct and normalize")
s3 = add_step(id, "Fit peaks with Voigt model")

finish_step(id, s1)
upload_to_experiment(id, "spectra.csv")
tag_experiment(id, ["ftir", "sample-a"])
```

### Search and browse

```julia
exps = search_experiments(tags=["ftir"])
print_experiments(exps)

items = search_items(query="MoS2")
print_items(items)
```

### Link entities

```julia
sample_id = create_item(title="MoS2 sample A", category=5)
link_experiment_to_item(id, sample_id)
link_experiments(id, previous_experiment_id)
```

### Idempotent logging

```julia
log_to_elab(
    title = "PL fit results",
    body  = "<h1>Results</h1><p>Peak at 632 nm</p>",
    tags  = ["pl", "sample-a"],
    attachments = ["figures/pl_fit.pdf"]
)
```

`log_to_elab` writes a `.elab_id` file next to the running script (from `Base.PROGRAM_FILE`). If you re-run the script with the same `title`, it updates the existing experiment instead of creating a duplicate. See [Idempotent Logging](@ref) for a deeper walkthrough.

## Caching

Downloaded files are cached locally in `~/.cache/elabftw/`. The cache is checked before making API requests. Use [`clear_elabftw_cache`](@ref) to clear it and [`elabftw_cache_info`](@ref) to check usage.

## Troubleshooting

### `elabftw_enabled()` returns `false`

The `ELABFTW_URL` and `ELABFTW_API_KEY` environment variables are missing or empty. Check with:

```bash
echo $ELABFTW_URL
echo $ELABFTW_API_KEY
```

If they're set but the package loaded before the variables were exported, configure manually:

```julia
configure_elabftw(url=ENV["ELABFTW_URL"], api_key=ENV["ELABFTW_API_KEY"])
```

### "Authentication failed"

The API key is invalid or expired. Generate a new one in **Settings → API Keys** in the eLabFTW web UI.

### "Permission denied"

The key doesn't have write permission. Create a new key with **Read/Write** access level.

### "File not found" on upload

The path passed to `upload_to_experiment`, `upload_to_item`, or `log_to_elab`'s `attachments` doesn't exist. Use absolute paths or paths relative to your current working directory (`pwd()`).

## Documentation Layout

- **Tutorials** — end-to-end walkthroughs for complete workflows (iterative experiments, samples and linking)
- **How-To Guides** — focused recipes (auth configuration, tagging conventions)
- **Reference** — full API documentation grouped by category
