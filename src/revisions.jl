# Entity body revisions and rollback.
#
# The server creates revisions automatically when an entity's body changes —
# subject to the instance's `max_revisions`, `min_days_revisions`, and
# `min_delta_revisions` configuration, so not every edit produces one. There
# is no API to create or delete individual revisions.

"""
    list_revisions(entity_type::Symbol, entity_id::Int) -> Vector{Dict}

List saved body revisions for an entity. `entity_type` is `:experiments`,
`:items`, or `:experiments_templates`.

Each row is a summary (no body text) — `id`, `content_type`, `created_at`,
`fullname`. Fetch individual revision content with [`get_revision`](@ref).

# Example
```julia
for r in list_revisions(:items, 42)
    println(r["created_at"], " by ", r["fullname"])
end
```
"""
function list_revisions(entity_type::Symbol, entity_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/revisions"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    get_revision(entity_type::Symbol, entity_id::Int, revision_id::Int) -> Dict

Retrieve a single revision with its full content. The returned `Dict`
includes `body`, `body_html`, and authorship metadata.

# Example
```julia
rev = get_revision(:items, 42, 2456)
println(rev["body"])
```
"""
function get_revision(entity_type::Symbol, entity_id::Int, revision_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/revisions/$revision_id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    restore_revision(entity_type::Symbol, entity_id::Int, revision_id::Int) -> Dict

Restore an entity's body to the state captured in a revision. Returns the
revision record (now reflecting the entity's active body). Restoring does
**not** create a new revision of the state being replaced — the previous
body is overwritten.

# Example
```julia
# Undo a bad edit by restoring the most recent revision
revs = list_revisions(:experiments, 17)
restore_revision(:experiments, 17, revs[1]["id"])
```
"""
function restore_revision(entity_type::Symbol, entity_id::Int, revision_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/revisions/$revision_id"
    response = _elabftw_patch(url, Dict{String, Any}("action" => "replace"))
    return JSON.parse(String(response.body))
end
