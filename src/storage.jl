# Storage units and containers

"""
    list_storage_units(; hierarchy::Bool=false) -> Vector{Dict}

List storage data. Two modes:

- `hierarchy=false` (default) — returns **container assignments**: flat rows
  of the form `(entity → storage unit, quantity)` across the whole team.
  Useful for "where is everything in our inventory?" views.
- `hierarchy=true` — returns **storage units** (freezers, shelves, boxes)
  with `parent_id`, `full_path`, `level_depth`, and `children_count`. Use
  this to render the storage tree.

The default mode is the misleadingly-named endpoint that eLabFTW exposes at
`GET /storage_units` without parameters — it lists *containers*, not units.

# Example
```julia
tree = list_storage_units(hierarchy=true)
for node in tree
    println(repeat("  ", node["level_depth"]), node["name"])
end

rows = list_storage_units()
for r in rows
    println(r["full_path"], " ← ", r["entity_title"],
            " (", r["qty_stored"], " ", r["qty_unit"], ")")
end
```
"""
function list_storage_units(; hierarchy::Bool=false)
    _check_enabled()
    query = hierarchy ? "?hierarchy=true" : ""
    url = "$(_elabftw_config.url)/api/v2/storage_units$query"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    get_storage_unit(id::Int) -> Dict

Retrieve a single storage unit by ID. Returns `id`, `name`, `parent_id`,
`full_path`, and `level_depth`.
"""
function get_storage_unit(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/storage_units/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_storage_unit(; name, parent_id=nothing) -> Int

Create a storage unit. Returns the new unit's ID. Pass `parent_id` to nest
under an existing unit; omit it for a root-level unit.

# Example
```julia
freezer = create_storage_unit(name="Freezer A")
drawer1 = create_storage_unit(name="Drawer 1", parent_id=freezer)
```
"""
function create_storage_unit(; name::String, parent_id::Union{Int, Nothing}=nothing)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/storage_units"
    payload = Dict{String, Any}("name" => name)
    !isnothing(parent_id) && (payload["parent_id"] = parent_id)
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    rename_storage_unit(id::Int, name::String)

Rename a storage unit. PATCH only supports renaming — re-parenting is not
accepted by the API. To move a unit, delete it (after emptying children and
containers) and re-create it under the new parent.
"""
function rename_storage_unit(id::Int, name::String)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/storage_units/$id"
    _elabftw_patch(url, Dict{String, Any}("name" => name))
    return nothing
end

"""
    delete_storage_unit(id::Int)

Delete a storage unit. Fails with HTTP 422 if the unit has child units or
attached containers — empty those first.
"""
function delete_storage_unit(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/storage_units/$id"
    _elabftw_delete(url)
    return nothing
end

"""
    list_containers(entity_type::Symbol, entity_id::Int) -> Vector{Dict}

List containers (storage assignments) attached to an entity.

`entity_type` is `:experiments`, `:items`, `:experiments_templates`, or
`:items_types`. Each row has `id` (the container row ID — use this for
`get_container`/`update_container`/`delete_container`), `storage_id`,
`qty_stored`, `qty_unit`, `storage_name`, and `full_path`.

# Example
```julia
containers = list_containers(:items, 42)
for c in containers
    println(c["full_path"], ": ", c["qty_stored"], " ", c["qty_unit"])
end
```
"""
function list_containers(entity_type::Symbol, entity_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/containers"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    get_container(entity_type::Symbol, entity_id::Int, container_id::Int) -> Dict

Retrieve a single container entry by row ID.

!!! warning
    The server keys containers by a global row ID and does not check that
    the row belongs to the entity in the URL. Always pass a `container_id`
    returned by `list_containers` on the same entity.
"""
function get_container(entity_type::Symbol, entity_id::Int, container_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/containers/$container_id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_container(entity_type, entity_id; storage_id, qty_stored, qty_unit="") -> Int

Attach an entity to a storage unit with a quantity. Returns the new
container row ID.

# Arguments
- `entity_type::Symbol` — `:experiments`, `:items`, `:experiments_templates`,
  or `:items_types`
- `entity_id::Int` — the entity being stored
- `storage_id::Int` — the storage unit that holds it (required)
- `qty_stored::Real` — amount stored (required)
- `qty_unit::String` — one of `"bar"`, `"•"`, `"m"`, `"μL"`, `"mL"`, `"L"`,
  `"μg"`, `"mg"`, `"g"`, `"kg"`. Other values are accepted but stored
  truncated to 10 characters — stick to the enum.

# Implementation note
The server's `Location` header on create points at an unusable
`containers2items/{storage_id}` URL, so this function re-lists the
entity's containers and returns the newest row with the matching
`storage_id`.

# Example
```julia
cid = create_container(:items, 42; storage_id=7, qty_stored=50, qty_unit="mL")
```
"""
function create_container(
    entity_type::Symbol,
    entity_id::Int;
    storage_id::Int,
    qty_stored::Real,
    qty_unit::String=""
)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/containers/$storage_id"
    payload = Dict{String, Any}(
        "storage_id" => storage_id,
        "qty_stored" => qty_stored
    )
    !isempty(qty_unit) && (payload["qty_unit"] = qty_unit)
    _elabftw_post(url, payload)
    rows = list_containers(entity_type, entity_id)
    matches = filter(r -> Int(r["storage_id"]) == storage_id, rows)
    isempty(matches) &&
        error("create_container: POST succeeded but no matching row found in listing")
    return maximum(r -> Int(r["id"]), matches)
end

"""
    update_container(entity_type, entity_id, container_id; qty_stored=nothing, qty_unit=nothing)

Update a container's quantity and/or unit. Only fields you pass are sent;
a call with no updates is a no-op.
"""
function update_container(
    entity_type::Symbol,
    entity_id::Int,
    container_id::Int;
    qty_stored::Union{Real, Nothing}=nothing,
    qty_unit::Union{String, Nothing}=nothing
)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/containers/$container_id"
    payload = Dict{String, Any}()
    !isnothing(qty_stored) && (payload["qty_stored"] = qty_stored)
    !isnothing(qty_unit) && (payload["qty_unit"] = qty_unit)
    isempty(payload) && return nothing
    _elabftw_patch(url, payload)
    return nothing
end

"""
    delete_container(entity_type::Symbol, entity_id::Int, container_id::Int)

Remove an entity's storage assignment.
"""
function delete_container(entity_type::Symbol, entity_id::Int, container_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/containers/$container_id"
    _elabftw_delete(url)
    return nothing
end
