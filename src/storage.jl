# Storage units and containers

"""
    list_storage_units(; hierarchy::Bool=false) -> Vector{Dict}

List storage data. Two modes:

- `hierarchy=false` (default) — returns **container assignments**: flat rows
  of the form `(entity → storage unit, quantity)` across the whole team.
  Useful for "where is everything in our inventory?" views.
- `hierarchy=true` — returns **storage units** (freezers, shelves, boxes)
  with `parent_id`, `full_path`, `capacity`, `occupancy`, `level_depth`, and
  `children_count`. Use this to render the storage tree.

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
`full_path`, `capacity` (`nothing` means unlimited), `occupancy` (containers
stored directly in the unit), and `level_depth`.
"""
function get_storage_unit(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/storage_units/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_storage_unit(; name, parent_id=nothing, capacity=nothing) -> Int

Create a storage unit. Returns the new unit's ID. Pass `parent_id` to nest
under an existing unit; omit it for a root-level unit. Pass `capacity` to cap
the number of containers the unit holds directly (`0` for a unit that only
holds other units); omit it for unlimited.

# Example
```julia
freezer = create_storage_unit(name="Freezer A")
drawer1 = create_storage_unit(name="Drawer 1", parent_id=freezer, capacity=96)
```
"""
function create_storage_unit(; name::String, parent_id::Union{Int, Nothing}=nothing,
    capacity::Union{Int, Nothing}=nothing)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/storage_units"
    payload = Dict{String, Any}("name" => name)
    !isnothing(parent_id) && (payload["parent_id"] = parent_id)
    !isnothing(capacity) && (payload["capacity"] = capacity)
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    update_storage_unit(id::Int; name=nothing, parent_id=nothing, capacity=nothing)

Update a storage unit's name, parent, and/or capacity. At least one field must
be provided.

# Arguments
- `name::String` — New name for the storage unit.
- `parent_id::Int` — New parent unit ID. Cannot be the unit itself or any
  of its descendants.
- `capacity::Int` — Maximum number of containers the unit holds directly
  (`0` for a unit that only holds other units). May be set below the current
  occupancy. Resetting a unit to unlimited needs an explicit `null` and
  cannot be expressed here; use the `elabftw_http` escape hatch.

# Example
```julia
update_storage_unit(5; capacity=96)
update_storage_unit(5; name="Freezer B")
update_storage_unit(5; parent_id=2)
update_storage_unit(5; name="Freezer B", parent_id=2)
```
"""
function update_storage_unit(id::Int;
    name::Union{String, Nothing}=nothing,
    parent_id::Union{Int, Nothing}=nothing,
    capacity::Union{Int, Nothing}=nothing,
)
    _check_enabled()
    all(isnothing, (name, parent_id, capacity)) &&
        throw(ArgumentError("update_storage_unit: specify at least one of name, parent_id, capacity"))
    url = "$(_elabftw_config.url)/api/v2/storage_units/$id"
    payload = Dict{String, Any}()
    isnothing(name) || (payload["name"] = name)
    isnothing(parent_id) || (payload["parent_id"] = parent_id)
    isnothing(capacity) || (payload["capacity"] = capacity)
    _elabftw_patch(url, payload)
    return nothing
end

"""
    rename_storage_unit(id::Int, name::String; parent_id=nothing)

Rename a storage unit. Optionally pass `parent_id` to move it to a new
parent at the same time. Pass `parent_id=nothing` (the default) to leave
the parent unchanged; the server also accepts an explicit `parent_id=null`
payload to move a unit to the root — use the `elabftw_http` escape hatch
for that case.
"""
function rename_storage_unit(id::Int, name::String;
    parent_id::Union{Int, Nothing}=nothing)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/storage_units/$id"
    payload = Dict{String, Any}("name" => name)
    isnothing(parent_id) || (payload["parent_id"] = parent_id)
    _elabftw_patch(url, payload)
    return nothing
end

"""
    delete_storage_unit(id::Int)

Delete a storage unit. Fails if the unit has child units or attached
containers — empty those first.

# Throws
- `ClientError` (status 422) — the unit still has children or containers.
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

# Throws
- `ClientError` (400) — the storage unit has a `capacity` and is already full.
- `ParseError` — the POST succeeded but the follow-up listing has no row
  matching `storage_id`. Indicates server behavior has drifted; open an issue.
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
        throw(ParseError("create_container: POST succeeded but no matching row found in listing"))
    return maximum(r -> Int(r["id"]), matches)
end

"""
    update_container(entity_type, entity_id, container_id; qty_stored=nothing, qty_unit=nothing, storage_id=nothing)

Update a container's quantity, unit, and/or storage location. Only fields
you pass are sent; a call with no updates is a no-op.

Pass `storage_id` to move the container to a different storage unit while
preserving the container row's `id` and `created_at`. Requires write access
on the parent entity (and `can_manage_inventory_locations` when the instance
has `inventory_require_edit_rights=1`). A move is rejected with a
`ClientError` (400) when the destination unit has a `capacity` and is
already full.
"""
function update_container(
    entity_type::Symbol,
    entity_id::Int,
    container_id::Int;
    qty_stored::Union{Real, Nothing}=nothing,
    qty_unit::Union{String, Nothing}=nothing,
    storage_id::Union{Int, Nothing}=nothing,
)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/containers/$container_id"
    payload = Dict{String, Any}()
    !isnothing(qty_stored) && (payload["qty_stored"] = qty_stored)
    !isnothing(qty_unit) && (payload["qty_unit"] = qty_unit)
    !isnothing(storage_id) && (payload["storage_id"] = storage_id)
    isempty(payload) && return nothing
    _elabftw_patch(url, payload)
    return nothing
end

"""
    delete_container(entity_type::Symbol, entity_id::Int, container_id::Int)

Remove an entity's storage assignment. Takes no body.

If the team that owns the entity has `capture_container_deletion_reason`
enabled, the server rejects this with a `ClientError` (400); use
[`destroy_container`](@ref) instead, which supplies a deletion reason.
"""
function delete_container(entity_type::Symbol, entity_id::Int, container_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/containers/$container_id"
    _elabftw_delete(url)
    return nothing
end

"""
    destroy_container(entity_type, entity_id, container_id; deletion_reason=nothing, deletion_comment=nothing)

Remove an entity's storage assignment, recording why. Sends
`PATCH .../containers/{id}` with `action: destroy`. Required instead of
[`delete_container`](@ref) when the owning team has
`capture_container_deletion_reason` enabled; the reason is then recorded in
the parent entity's changelog. Requires an eLabFTW server running 6.x or later.

# Arguments
- `deletion_reason::Int` — one of `10` used up in authorised work, `20` no
  longer required, `30` consent withdrawn or use prohibited, `40` approval or
  retention period ended, `50` shelf life exceeded, `60` unsuitable for
  intended use, `70` contaminated, `80` storage or transport incident,
  `90` collected or registered in error, `100` other. Mandatory when the team
  captures deletion reasons.
- `deletion_comment::String` — free text (at most 255 characters, longer is
  rejected). Mandatory when `deletion_reason` is `100`.

Returns the container as it was just before removal.

# Example
```julia
destroy_container(:items, 42, cid; deletion_reason=70, deletion_comment="spilled in transit")
```
"""
function destroy_container(
    entity_type::Symbol,
    entity_id::Int,
    container_id::Int;
    deletion_reason::Union{Int, Nothing}=nothing,
    deletion_comment::Union{String, Nothing}=nothing,
)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/containers/$container_id"
    payload = Dict{String, Any}("action" => "destroy")
    isnothing(deletion_reason) || (payload["deletion_reason"] = deletion_reason)
    isnothing(deletion_comment) || (payload["deletion_comment"] = deletion_comment)
    response = _elabftw_patch(url, payload)
    return JSON.parse(String(response.body))
end
