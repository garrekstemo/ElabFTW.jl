"""
# ElabFTW.jl — Julia client for eLabFTW API v2

Full read/write access to eLabFTW for experiment logging,
item/resource management, batch operations, analysis steps, cross-entity
linking, comments, templates, scheduler events, and compounds.

# Configuration

Set up eLabFTW connection (typically in startup.jl or environment):

```julia
using ElabFTW
configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
test_connection()  # Verify credentials
```

Or set `ELABFTW_URL` and `ELABFTW_API_KEY` environment variables for
automatic configuration on package load.

# Usage

```julia
# Log analysis results
log_to_elab(title="FTIR fit", body="Results here")

# Track analysis steps
id = create_experiment(title="TA kinetics analysis")
s1 = add_step(id, "Load and inspect raw data")
s2 = add_step(id, "Fit single exponential with IRF")
finish_step(id, s1)

# Link related experiments
link_experiments(id, previous_id)

# Manage lab resources
sample_id = create_item(title="MoS2 sample A", category=5)
link_experiment_to_item(id, sample_id)

# Browse experiments and items
exps = search_experiments(tags=["ftir"])
print_experiments(exps)
```

# Caching

Downloaded files are cached in `~/.cache/elabftw/`. The cache is checked
before making API requests. Clear with `clear_elabftw_cache()`.
"""
module ElabFTW

using HTTP, JSON, Dates

# Infrastructure (must be loaded first)
include("config.jl")
include("http.jl")
include("cache.jl")

# Generic helpers (used by entity-specific wrappers)
include("entity_helpers.jl")
include("subresource_helpers.jl")

# Entity-specific public APIs
include("experiments.jl")
include("items.jl")

# Cross-cutting features
include("links.jl")
include("comments.jl")
include("templates.jl")
include("team.jl")

# Batch operations
include("batch.jl")

# Additional API coverage
include("events.jl")
include("compounds.jl")
include("utility.jl")

# High-level provenance and printing
include("provenance.jl")
include("printing.jl")

# Configuration
export configure_elabftw, elabftw_enabled, disable_elabftw, enable_elabftw
export test_connection

# Cache
export clear_elabftw_cache, elabftw_cache_info
export download_elabftw_file, download_item_upload, download_experiment_upload

# Experiments
export create_experiment, create_from_template
export update_experiment, upload_to_experiment
export tag_experiment, untag_experiment, list_tags, clear_tags
export list_experiment_tags, clear_experiment_tags
export get_experiment, delete_experiment, duplicate_experiment
export list_experiments, search_experiments
export list_experiment_uploads, delete_experiment_upload
export add_step, list_steps, finish_step
export link_experiments, list_experiment_links, unlink_experiments

# Items
export create_item, get_item, update_item, delete_item, duplicate_item
export list_items, search_items
export tag_item, untag_item, list_item_tags, clear_item_tags
export upload_to_item, list_item_uploads, delete_item_upload
export add_item_step, list_item_steps, finish_item_step

# Cross-entity links
export link_experiment_to_item, unlink_experiment_from_item, list_experiment_item_links
export link_item_to_experiment, unlink_item_from_experiment, list_item_experiment_links
export link_items, unlink_items, list_item_links

# Comments
export create_comment, list_comments, get_comment, update_comment, delete_comment
export comment_experiment, list_experiment_comments
export comment_item, list_item_comments

# Templates
export list_experiment_templates, create_experiment_template
export get_experiment_template, update_experiment_template
export delete_experiment_template, duplicate_experiment_template
export list_items_types, create_items_type, get_items_type
export update_items_type, delete_items_type

# Team
export list_team_tags, rename_team_tag, delete_team_tag
export list_experiments_categories, list_items_categories

# Batch
export delete_experiments, tag_experiments, update_experiments
export delete_items, tag_items, update_items

# Events
export list_events, create_event, get_event, update_event, delete_event

# Compounds
export list_compounds, create_compound, get_compound, delete_compound
export link_compound, list_compound_links

# Utility
export instance_info
export list_favorite_tags, add_favorite_tag, remove_favorite_tag
export import_file, create_export, download_export

# Printing
export print_experiments, print_items, print_tags

# Provenance
export log_to_elab, tags_from_sample

# Auto-configure from environment variables
function __init__()
    url = get(ENV, "ELABFTW_URL", nothing)
    key = get(ENV, "ELABFTW_API_KEY", nothing)
    if !isnothing(url) && !isnothing(key) && !isempty(url) && !isempty(key)
        configure_elabftw(url=url, api_key=key)
    end
end

end # module ElabFTW
