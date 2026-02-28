# Provenance helpers: log_to_elab, tags_from_sample

# =============================================================================
# .elab_id helpers (idempotent logging)
# =============================================================================

"""Return path for .elab_id file next to the running script, or nothing."""
function _elab_id_path()
    prog = Base.PROGRAM_FILE
    (isempty(prog) || !isfile(prog)) && return nothing
    return joinpath(dirname(abspath(prog)), ".elab_id")
end

"""Read existing .elab_id file. Returns (id=Int, title=String) or nothing."""
function _read_elab_id()
    path = _elab_id_path()
    (isnothing(path) || !isfile(path)) && return nothing
    try
        data = JSON.parsefile(path)
        return (id=data["id"]::Int, title=get(data, "title", "")::String)
    catch
        return nothing
    end
end

"""Write .elab_id file next to the running script."""
function _write_elab_id(id::Int, title::String)
    path = _elab_id_path()
    isnothing(path) && return
    open(path, "w") do io
        JSON.print(io, Dict("id" => id, "title" => title), 2)
    end
end

# =============================================================================
# Attachment replacement (idempotent uploads)
# =============================================================================

"""Replace attachments by filename — delete existing with same name, then upload."""
function _replace_attachments(experiment_id::Int, filepaths::Vector{String})
    isempty(filepaths) && return
    exp = get_experiment(experiment_id)
    existing = get(exp, "uploads", [])
    for filepath in filepaths
        fname = basename(filepath)
        for upload in existing
            if get(upload, "real_name", "") == fname
                _delete_entity_upload("experiments", experiment_id, upload["id"])
                break
            end
        end
        upload_to_experiment(experiment_id, filepath; comment=fname)
    end
end

# =============================================================================
# Idempotent log_to_elab
# =============================================================================

"""
    log_to_elab(; title, body, attachments, tags, category, metadata) -> Int

Log analysis results to eLabFTW. Idempotent: if a `.elab_id` file exists next
to the running script with a matching title, updates the existing experiment
instead of creating a new one.

Returns the experiment ID.

# Examples
```julia
# First run: creates experiment, writes .elab_id
log_to_elab(title="FTIR: CN stretch fit", body="Results here")

# Re-run: updates existing experiment
log_to_elab(title="FTIR: CN stretch fit", body="Updated results")
```
"""
function log_to_elab(;
    title::String,
    body::String = "",
    attachments::Vector{String} = String[],
    tags::Vector{String} = String[],
    category::Union{Int, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    existing = _read_elab_id()

    if !isnothing(existing) && existing.title == title
        # Update existing experiment
        id = existing.id
        update_experiment(id; title=title, body=body)
        _replace_attachments(id, attachments)
        if !isempty(tags)
            tag_experiment(id, tags)
        end
        exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
        println("eLabFTW: updated experiment #$id")
        println("  $exp_url")
    else
        # Create new experiment
        id = create_experiment(; title=title, body=body, category=category, metadata=metadata)
        for filepath in attachments
            upload_to_experiment(id, filepath; comment=basename(filepath))
        end
        if !isempty(tags)
            tag_experiment(id, tags)
        end
        _write_elab_id(id, title)
        exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
        println("eLabFTW: created experiment #$id")
        println("  $exp_url")
    end

    return id
end

"""
    tags_from_sample(sample::Dict; include=nothing, exclude=["_id", "path", "date"]) -> Vector{String}

Extract tags from sample metadata dictionary.

By default, extracts values from common fields (solute, solvent, material, etc.)
and excludes internal fields (_id, path, date).

# Arguments
- `sample::Dict` — Sample metadata (e.g., from `spec.sample`)
- `include::Vector{Symbol}` — Only include these fields (default: all except excluded)
- `exclude::Vector{String}` — Fields to skip (default: ["_id", "path", "date"])

# Example
```julia
sample = Dict("solute" => "NH4SCN", "solvent" => "DMF", "concentration" => "1.0M")
tags = tags_from_sample(sample)
# => ["NH4SCN", "DMF", "1.0M"]
```
"""
function tags_from_sample(sample::Dict;
    include::Union{Nothing, Vector{Symbol}} = nothing,
    exclude::Vector{String} = ["_id", "path", "date", "pathlength"]
)
    tags = String[]

    for (k, v) in sample
        k in exclude && continue
        if !isnothing(include) && Symbol(k) ∉ include
            continue
        end
        v isa String || continue
        isempty(v) && continue
        push!(tags, v)
    end

    return unique(tags)
end
