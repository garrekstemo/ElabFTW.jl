# Team-level tag and category management

"""
    list_team_tags() -> Vector{Dict}

List all tags in the team registry.

# Example
```julia
tags = list_team_tags()
for t in tags
    println(t["id"], ": ", t["tag"])
end
```
"""
function list_team_tags()
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/teams/current/tags"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    rename_team_tag(tag_id::Int, new_name::String)

Rename a tag in the team registry. Admin-only operation.

# Example
```julia
rename_team_tag(7, "ftir-analysis")
```
"""
function rename_team_tag(tag_id::Int, new_name::String)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/teams/current/tags/$tag_id"
    _elabftw_patch(url, Dict("action" => "updatetag", "tag" => new_name))
    return nothing
end

"""
    delete_team_tag(tag_id::Int)

Delete a tag from the team registry. Removes the tag from all entity references.
Admin-only operation.

# Example
```julia
delete_team_tag(7)
```
"""
function delete_team_tag(tag_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/teams/current/tags/$tag_id"
    _elabftw_delete(url)
    return nothing
end

"""
    list_experiments_categories() -> Vector{Dict}

List all experiment categories for the current team.

# Example
```julia
cats = list_experiments_categories()
for c in cats
    println(c["id"], ": ", c["title"])
end
```
"""
function list_experiments_categories()
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/teams/current/experiments_categories"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    list_items_categories() -> Vector{Dict}

List all item types (resource categories) for the current team.

# Example
```julia
types = list_items_categories()
for t in types
    println(t["id"], ": ", t["title"])
end
```
"""
function list_items_categories()
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/teams/current/resources_categories"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

# Map public Symbol → server endpoint segment. The server uses the singular
# "resources" (not "items") for item categories but plural "items_status"
# for item statuses, and experiments_* is consistent on both sides. Keep this
# private so callers don't have to memorize the asymmetry.
function _statuslike_path(kind::Symbol, entity_type::Symbol)
    kind === :category || kind === :status ||
        throw(ArgumentError("_statuslike_path: kind must be :category or :status"))
    entity_type === :experiments || entity_type === :items ||
        throw(ArgumentError("_statuslike_path: entity_type must be :experiments or :items"))
    if kind === :category
        seg = entity_type === :experiments ? "experiments_categories" : "resources_categories"
    else
        seg = entity_type === :experiments ? "experiments_status" : "items_status"
    end
    return "$(_elabftw_config.url)/api/v2/teams/current/$seg"
end

function _statuslike_create(kind::Symbol, entity_type::Symbol, title::String,
                            color::String, default::Int)
    _check_enabled()
    url = _statuslike_path(kind, entity_type)
    # POST uses `name`; GET/PATCH use `title`. Translate.
    payload = Dict{String, Any}("name" => title, "default" => default)
    # Server rejects empty `color` with HTTP 400, so only send when given.
    isempty(color) || (payload["color"] = color)
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

function _statuslike_get(kind::Symbol, entity_type::Symbol, id::Int)
    _check_enabled()
    url = "$(_statuslike_path(kind, entity_type))/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _statuslike_update(kind::Symbol, entity_type::Symbol, id::Int;
                            title::Union{String, Nothing}=nothing,
                            color::Union{String, Nothing}=nothing,
                            default::Union{Int, Nothing}=nothing)
    _check_enabled()
    all(isnothing, (title, color, default)) &&
        throw(ArgumentError("update_*: specify at least one of title, color, default"))
    url = "$(_statuslike_path(kind, entity_type))/$id"
    payload = Dict{String, Any}()
    isnothing(title) || (payload["title"] = title)
    isnothing(color) || (payload["color"] = color)
    isnothing(default) || (payload["is_default"] = default)
    response = _elabftw_patch(url, payload)
    return JSON.parse(String(response.body))
end

function _statuslike_delete(kind::Symbol, entity_type::Symbol, id::Int)
    _check_enabled()
    url = "$(_statuslike_path(kind, entity_type))/$id"
    _elabftw_delete(url)
    return nothing
end

"""
    create_category(entity_type::Symbol; title, color="", default=0) -> Int

Create a new category. `entity_type` is `:experiments` or `:items`.
Returns the new category ID.

# Arguments
- `title::String` — Category name
- `color::String` — 6-char hex (no leading `#`), e.g. `"2ecc71"`
- `default::Int` — `1` makes this the team's default, `0` otherwise

# Example
```julia
create_category(:experiments; title="Draft", color="999999")
```
"""
create_category(entity_type::Symbol; title::String, color::String="",
                default::Int=0) =
    _statuslike_create(:category, entity_type, title, color, default)

"""
    get_category(entity_type::Symbol, id::Int) -> Dict

Retrieve a single category.
"""
get_category(entity_type::Symbol, id::Int) =
    _statuslike_get(:category, entity_type, id)

"""
    update_category(entity_type::Symbol, id::Int; title=nothing, color=nothing, default=nothing) -> Dict

Update a category's title, color, and/or default flag. At least one
field must be provided. Returns the updated category.
"""
update_category(entity_type::Symbol, id::Int;
                title::Union{String, Nothing}=nothing,
                color::Union{String, Nothing}=nothing,
                default::Union{Int, Nothing}=nothing) =
    _statuslike_update(:category, entity_type, id;
        title=title, color=color, default=default)

"""
    delete_category(entity_type::Symbol, id::Int)

Soft-delete a category. The server marks the entry as deleted (`state=3`)
rather than removing it; a subsequent `get_category` will still return the
record with `state=3`.
"""
delete_category(entity_type::Symbol, id::Int) =
    _statuslike_delete(:category, entity_type, id)

"""
    list_status(entity_type::Symbol) -> Vector{Dict}

List the experiment or item statuses for the current team.
`entity_type` is `:experiments` or `:items`.
"""
function list_status(entity_type::Symbol)
    _check_enabled()
    url = _statuslike_path(:status, entity_type)
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_status(entity_type::Symbol; title, color="", default=0) -> Int

Create a new status. See [`create_category`](@ref) for argument semantics.
"""
create_status(entity_type::Symbol; title::String, color::String="",
              default::Int=0) =
    _statuslike_create(:status, entity_type, title, color, default)

"""
    get_status(entity_type::Symbol, id::Int) -> Dict

Retrieve a single status.
"""
get_status(entity_type::Symbol, id::Int) =
    _statuslike_get(:status, entity_type, id)

"""
    update_status(entity_type::Symbol, id::Int; title=nothing, color=nothing, default=nothing) -> Dict

Update a status. See [`update_category`](@ref) for argument semantics.
"""
update_status(entity_type::Symbol, id::Int;
              title::Union{String, Nothing}=nothing,
              color::Union{String, Nothing}=nothing,
              default::Union{Int, Nothing}=nothing) =
    _statuslike_update(:status, entity_type, id;
        title=title, color=color, default=default)

"""
    delete_status(entity_type::Symbol, id::Int)

Soft-delete a status (server marks `state=3`). See [`delete_category`](@ref).
"""
delete_status(entity_type::Symbol, id::Int) =
    _statuslike_delete(:status, entity_type, id)
