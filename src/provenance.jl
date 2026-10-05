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
    log_to_elab(; title, body, content_type, attachments, tags, category, metadata, template) -> Int

Log analysis results to eLabFTW. Idempotent: if a `.elab_id` file exists next
to the running script with a matching title, updates the existing experiment
instead of creating a new one.

`body` is sent with `content_type` — `2` = Markdown (default), `1` = HTML.

Pass `template` (an experiment template ID) when the team only allows
creating experiments from a template. The new experiment copies the template,
and a non-empty `body` or a `category` replaces the template's. `metadata` is
merged into the template's: values under `extra_fields` fill the template's
fields (the template keeps their definitions), and other top-level keys are
added. `template` is only used on the first run.

Returns the experiment ID.

# Idempotency mechanism

The first run creates the experiment and writes a `.elab_id` marker file in
the directory of the running script (`Base.PROGRAM_FILE`). Re-runs with the
same `title` find the marker and update that experiment: body and metadata
are replaced, tags are reset to the ones passed, and attachments with
matching filenames are replaced.

!!! warning
    In the REPL or a notebook `Base.PROGRAM_FILE` is empty, so no `.elab_id`
    marker can be written and every call creates a new experiment. Run your
    analysis as a script (`julia analyze.jl`) for idempotent updates.

# Examples
```julia
# First run: creates experiment, writes .elab_id next to the script
log_to_elab(title="FTIR: CN stretch fit", body="Results here")

# Re-run: updates the existing experiment
log_to_elab(title="FTIR: CN stretch fit", body="Updated results",
            attachments=["fit_results.csv"], tags=["ftir"])

# Team requires templates: create from template 603
log_to_elab(title="FTIR: CN stretch fit", body="Results here", template=603)
```
"""
function log_to_elab(;
    title::String,
    body::String = "",
    content_type::Int = 2,
    attachments::Vector{String} = String[],
    tags::Vector{String} = String[],
    category::Union{Int, Nothing} = nothing,
    metadata::Union{Dict, AbstractString, Nothing} = nothing,
    template::Union{Int, Nothing} = nothing
)
    existing = _read_elab_id()

    if !isnothing(existing) && existing.title == title
        # Update existing experiment — propagate the same fields a fresh
        # create would. Re-runs must be idempotent: if the caller trims
        # `tags`, the experiment's tag set must shrink accordingly rather
        # than accumulate previous runs' labels.
        id = existing.id
        update_experiment(id; title=title, body=body, content_type=content_type, metadata=metadata)
        _replace_attachments(id, attachments)
        clear_experiment_tags(id)
        isempty(tags) || tag_experiment(id, tags)
        exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
        @info "eLabFTW: updated experiment" id url=exp_url
    else
        # Create new experiment
        if isnothing(template)
            id = create_experiment(; title=title, body=body, content_type=content_type, category=category, metadata=metadata)
        else
            # When copying a template the server ignores `body` and
            # `category`, and merges only `extra_fields` from `metadata`.
            # Set the rest with a follow-up update.
            id = _create_entity("experiments"; template=template, title=title, metadata=metadata)
            overrides = Dict{Symbol, Any}()
            isempty(body) || (overrides[:body] = body; overrides[:content_type] = content_type)
            isnothing(category) || (overrides[:category] = category)
            md = metadata isa AbstractString ? JSON.parse(metadata) : metadata
            extra = isnothing(md) ? nothing : filter(p -> String(p.first) != "extra_fields", md)
            if !isnothing(extra) && !isempty(extra)
                current = get_experiment(id)["metadata"]
                merged = Dict{String, Any}(isnothing(current) ? Dict() : JSON.parse(current))
                for (k, v) in extra
                    merged[String(k)] = v
                end
                overrides[:metadata] = merged
            end
            isempty(overrides) || update_experiment(id; overrides...)
        end
        for filepath in attachments
            upload_to_experiment(id, filepath; comment=basename(filepath))
        end
        if !isempty(tags)
            tag_experiment(id, tags)
        end
        _write_elab_id(id, title)
        exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
        @info "eLabFTW: created experiment" id url=exp_url
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
