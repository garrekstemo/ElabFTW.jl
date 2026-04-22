# Public items/resources API — thin wrappers over generic entity helpers.

# =============================================================================
# CRUD
# =============================================================================

"""
    create_item(; title, body, category, metadata) -> Int

Create a new item (resource) in eLabFTW. Returns the item ID.

Items represent lab resources: samples, instruments, reagents, etc.

# Arguments
- `title::String` — Item title
- `body::String` — Item body/description (supports markdown)
- `category::Union{Int, Nothing}` — Items type (category) ID
- `metadata::Union{Dict, Nothing}` — Extra metadata JSON

# Example
```julia
id = create_item(title="MoS2 sample A", category=5)
```
"""
function create_item(;
    title::String,
    body::String = "",
    category::Union{Int, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    return _create_entity("items"; title=title, body=body, category=category, metadata=metadata)
end

"""
    get_item(id::Int) -> Dict

Retrieve an item by ID.

# Example
```julia
item = get_item(42)
item["title"]
```
"""
get_item(id::Int) = _get_entity("items", id)

"""
    update_item(id::Int; title, body, metadata)

Update an existing item.

# Arguments
- `id::Int` — Item ID
- `title::String` — New title (optional)
- `body::String` — New body content (optional)
- `metadata::Union{Dict, Nothing}` — Extra metadata JSON (optional)

# Example
```julia
update_item(42; body="Updated sample description")
```
"""
function update_item(id::Int;
    title::Union{String, Nothing} = nothing,
    body::Union{String, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    return _update_entity("items", id; title=title, body=body, metadata=metadata)
end

"""
    delete_item(id::Int)

Delete an item from eLabFTW.

# Example
```julia
delete_item(42)
```
"""
function delete_item(id::Int)
    _delete_entity("items", id)
    println("Deleted item $id")
    return nothing
end

"""
    duplicate_item(id::Int) -> Int

Duplicate an item. Returns the new item ID.

# Example
```julia
new_id = duplicate_item(42)
```
"""
duplicate_item(id::Int) = _duplicate_entity("items", id)

# =============================================================================
# List / Search
# =============================================================================

"""
    list_items(; limit, offset, order, sort,
               cat, owner, state, status, scope,
               related, related_origin) -> Vector{Dict}

List items (resources) from eLabFTW with pagination, sorting, and filtering.

# Arguments
- `limit::Int` — Maximum number of results (default: 20)
- `offset::Int` — Skip first N results (default: 0)
- `order::Symbol` — Sort field: `:date`, `:title`, `:id`, `:rating`, `:lastchange`, ... (default: `:date`)
- `sort::Symbol` — Sort direction: `:desc`, `:asc` (default: `:desc`)
- `cat` — Category ID (`items_type` ID), or `Vector{Int}` for multiple
- `owner` — User ID, or `Vector{Int}` for multiple
- `state::Int` — 1 Normal, 2 Archived, 3 Deleted (default shows Normal only)
- `status::Int` — Status ID
- `scope::Int` — 1 self, 2 team, 3 everything
- `related::Int` + `related_origin::Symbol` — restrict to items linked to this entity

# Examples
```julia
list_items(limit=10)
list_items(state=2)                # archived items
list_items(cat=[104, 107])         # instruments + samples (QPS Lab)
list_items(related=17, related_origin=:experiments)
```
"""
function list_items(;
    limit::Int = 20,
    offset::Int = 0,
    order::Symbol = :date,
    sort::Symbol = :desc,
    cat::Union{Int, Vector{Int}, Nothing} = nothing,
    owner::Union{Int, Vector{Int}, Nothing} = nothing,
    state::Union{Int, Nothing} = nothing,
    status::Union{Int, Nothing} = nothing,
    scope::Union{Int, Nothing} = nothing,
    related::Union{Int, Nothing} = nothing,
    related_origin::Union{Symbol, Nothing} = nothing,
)
    return _list_entities("items";
        limit=limit, offset=offset, order=order, sort=sort,
        cat=cat, owner=owner, state=state, status=status, scope=scope,
        related=related, related_origin=related_origin)
end

"""
    search_items(; query, tags, limit, offset, order, sort,
                 cat, owner, state, status, scope, extended,
                 related, related_origin) -> Vector{Dict}

Search items (resources) in eLabFTW by text query, tags, and other filters.

All `list_items` filter kwargs apply, plus:

- `query::String` — Full-text search (title, body, elabid).
- `tags::Vector{String}` — Entries must have ALL listed tags.
- `extended::String` — Advanced DSL (e.g. `"rating:2 and title:MoS2"`).

# Examples
```julia
search_items(query="MoS2")
search_items(tags=["instrument"])
search_items(state=2, cat=104)
```
"""
function search_items(;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[],
    limit::Int = 20,
    offset::Int = 0,
    order::Symbol = :date,
    sort::Symbol = :desc,
    cat::Union{Int, Vector{Int}, Nothing} = nothing,
    owner::Union{Int, Vector{Int}, Nothing} = nothing,
    state::Union{Int, Nothing} = nothing,
    status::Union{Int, Nothing} = nothing,
    scope::Union{Int, Nothing} = nothing,
    extended::Union{String, Nothing} = nothing,
    related::Union{Int, Nothing} = nothing,
    related_origin::Union{Symbol, Nothing} = nothing,
)
    return _list_entities("items";
        query=query, tags=tags, limit=limit, offset=offset, order=order, sort=sort,
        cat=cat, owner=owner, state=state, status=status, scope=scope,
        extended=extended, related=related, related_origin=related_origin)
end

# =============================================================================
# Tags
# =============================================================================

"""
    tag_item(id::Int, tag::String)

Add a tag to an item.

# Example
```julia
tag_item(42, "mos2")
```
"""
tag_item(id::Int, tag::String) = _tag_entity("items", id, tag)

"""
    tag_item(id::Int, tags::Vector{String})

Add multiple tags to an item.
"""
tag_item(id::Int, tags::Vector{String}) = _tag_entity("items", id, tags)

"""
    untag_item(id::Int, tag_id::Int)

Remove a single tag from an item.
"""
untag_item(id::Int, tag_id::Int) = _untag_entity("items", id, tag_id)

"""
    list_item_tags(id::Int) -> Vector{Dict}

List all tags on an item.
"""
list_item_tags(id::Int) = _list_entity_tags("items", id)

"""
    clear_item_tags(id::Int)

Remove all tags from an item.
"""
clear_item_tags(id::Int) = _clear_entity_tags("items", id)

# =============================================================================
# Uploads
# =============================================================================

"""
    upload_to_item(id::Int, filepath::String; comment) -> Int

Upload a file attachment to an item. Returns the upload ID.
"""
function upload_to_item(id::Int, filepath::String; comment::String="")
    return _upload_to_entity("items", id, filepath; comment=comment)
end

"""
    list_item_uploads(id::Int; state=nothing) -> Vector{Dict}

List file uploads on an item. See [`list_experiment_uploads`](@ref) for the
`state` filter semantics.
"""
list_item_uploads(id::Int; state::Union{Int, Vector{Int}, Nothing}=nothing) =
    _list_entity_uploads("items", id; state=state)

"""
    update_item_upload(id::Int, upload_id::Int; real_name=nothing, comment=nothing, state=nothing) -> Dict

Modify upload attributes on an item. See [`update_experiment_upload`](@ref)
for argument semantics.
"""
update_item_upload(id::Int, upload_id::Int;
    real_name::Union{String, Nothing}=nothing,
    comment::Union{String, Nothing}=nothing,
    state::Union{Int, Nothing}=nothing,
) = _update_entity_upload("items", id, upload_id;
        real_name=real_name, comment=comment, state=state)

"""
    replace_item_upload(id::Int, upload_id::Int, filepath::String; comment="") -> Int

Replace an item upload. See [`replace_experiment_upload`](@ref).
"""
replace_item_upload(id::Int, upload_id::Int, filepath::String; comment::String="") =
    _replace_entity_upload("items", id, upload_id, filepath; comment=comment)

"""
    delete_item_upload(id::Int, upload_id::Int)

Delete a file upload from an item.
"""
delete_item_upload(id::Int, upload_id::Int) = _delete_entity_upload("items", id, upload_id)

# =============================================================================
# Steps
# =============================================================================

"""
    add_item_step(id::Int, body::String) -> Int

Add a step to an item. Returns the step ID.
"""
add_item_step(id::Int, body::String) = _add_entity_step("items", id, body)

"""
    list_item_steps(id::Int) -> Vector{Dict}

List all steps for an item.
"""
list_item_steps(id::Int) = _list_entity_steps("items", id)

"""
    finish_item_step(id::Int, step_id::Int)

Mark an item step as finished.
"""
finish_item_step(id::Int, step_id::Int) = _finish_entity_step("items", id, step_id)

"""
    delete_item_step(id::Int, step_id::Int)

Delete an analysis step from an item.
"""
delete_item_step(id::Int, step_id::Int) = _delete_entity_step("items", id, step_id)
