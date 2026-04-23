# PatchAction actions on experiments and items.
#
# The API overloads PATCH /experiments/{id} and PATCH /items/{id} to accept
# either regular field updates or an action directive (`{"action": "lock"}`,
# etc.). Exposed here as named wrappers so callers don't reach for raw
# JSON.

"""
    SIGN_MEANING :: Dict{Symbol, Int}

Mapping of signature-meaning symbols to the integer codes the eLabFTW API
requires. Used by [`sign_experiment`](@ref) and [`sign_item`](@ref).

| Symbol            | Code |
|-------------------|------|
| `:approval`       | 10   |
| `:authorship`     | 20   |
| `:responsibility` | 30   |
| `:review`         | 40   |
| `:safety`         | 50   |
"""
const SIGN_MEANING = Dict(
    :approval => 10,
    :authorship => 20,
    :responsibility => 30,
    :review => 40,
    :safety => 50,
)

function _resolve_meaning(m::Integer)
    Int(m) in values(SIGN_MEANING) ||
        throw(ArgumentError("sign: meaning must be one of $(sort(collect(values(SIGN_MEANING))))"))
    return Int(m)
end

function _resolve_meaning(m::Symbol)
    haskey(SIGN_MEANING, m) ||
        throw(ArgumentError("sign: unknown meaning :$m; use one of $(sort(collect(keys(SIGN_MEANING))))"))
    return SIGN_MEANING[m]
end

function _patch_action(
    entity_type::Symbol,
    entity_id::Int,
    action::String;
    passphrase::Union{String, Nothing}=nothing,
    meaning::Union{Int, Nothing}=nothing,
)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id"
    payload = Dict{String, Any}("action" => action)
    isnothing(passphrase) || (payload["passphrase"] = passphrase)
    isnothing(meaning) || (payload["meaning"] = meaning)
    response = _elabftw_patch(url, payload)
    return JSON.parse(String(response.body))
end

"""
    lock_experiment(id::Int) -> Dict

**Toggle** the lock state on an experiment. A locked experiment cannot be
edited. Calling this on an already-locked experiment unlocks it.

Returns the updated experiment record.

# Example
```julia
lock_experiment(42)    # locks
lock_experiment(42)    # unlocks
```
"""
lock_experiment(id::Int) = _patch_action(:experiments, id, "lock")

"""
    lock_item(id::Int) -> Dict

**Toggle** the lock state on an item (resource). See [`lock_experiment`](@ref).
"""
lock_item(id::Int) = _patch_action(:items, id, "lock")

"""
    pin_experiment(id::Int) -> Dict

**Toggle** the pin state on an experiment. Pinning bookmarks the entity
in the user's dashboard. Calling this on an already-pinned experiment
unpins it.

Returns the updated experiment record.
"""
pin_experiment(id::Int) = _patch_action(:experiments, id, "pin")

"""
    pin_item(id::Int) -> Dict

**Toggle** the pin state on an item (resource). See [`pin_experiment`](@ref).
"""
pin_item(id::Int) = _patch_action(:items, id, "pin")

"""
    force_lock_experiment(id::Int) -> Dict

Admin override — lock an experiment regardless of who locked it or the
current lock state. Unlike [`lock_experiment`](@ref), this is not a toggle.
Requires admin permission on the team; non-admin callers get `PermissionError`.
"""
force_lock_experiment(id::Int) = _patch_action(:experiments, id, "forcelock")

"""
    force_lock_item(id::Int) -> Dict

Admin override for item lock. See [`force_lock_experiment`](@ref).
"""
force_lock_item(id::Int) = _patch_action(:items, id, "forcelock")

"""
    force_unlock_experiment(id::Int) -> Dict

Admin override — unlock an experiment that was locked by another user.
Requires admin permission.
"""
force_unlock_experiment(id::Int) = _patch_action(:experiments, id, "forceunlock")

"""
    force_unlock_item(id::Int) -> Dict

Admin override for item unlock. See [`force_unlock_experiment`](@ref).
"""
force_unlock_item(id::Int) = _patch_action(:items, id, "forceunlock")

"""
    timestamp_experiment(id::Int) -> Dict

RFC 3161 timestamp an experiment. Requires the eLabFTW instance to be
configured with a trusted timestamping service. Marks the entity's
`timestamped=1` and records `timestamped_at`.

Returns the updated experiment record.

# Example
```julia
stamped = timestamp_experiment(42)
println(stamped["timestamped_at"])
```
"""
timestamp_experiment(id::Int) = _patch_action(:experiments, id, "timestamp")

"""
    timestamp_item(id::Int) -> Dict

RFC 3161 timestamp an item (resource). See [`timestamp_experiment`](@ref).
"""
timestamp_item(id::Int) = _patch_action(:items, id, "timestamp")

"""
    sign_experiment(id::Int; passphrase, meaning) -> Dict

Cryptographically sign an experiment with the user's signing key.

# Arguments
- `passphrase::String` — the passphrase for the caller's signing key
- `meaning` — an `Int` (10, 20, 30, 40, 50) or `Symbol` (`:approval`,
  `:authorship`, `:responsibility`, `:review`, `:safety`). See
  [`SIGN_MEANING`](@ref).

Requires the eLabFTW instance to be configured with signing keys. If keys
are not configured, the server returns HTTP 500 (this surfaces as a
[`ServerError`](@ref) after retry exhaustion).

# Example
```julia
sign_experiment(42; passphrase="secret", meaning=:approval)
```

# Throws
- `ArgumentError` — `meaning` is not in `SIGN_MEANING` (bad `Int` or unknown `Symbol`).
- `ServerError` — signing keys not configured or passphrase wrong. The server
  returns HTTP 500 rather than 4xx for these; after retry exhaustion this
  surfaces as [`ServerError`](@ref).
"""
function sign_experiment(id::Int;
    passphrase::AbstractString,
    meaning::Union{Integer, Symbol},
)
    _patch_action(:experiments, id, "sign";
        passphrase=String(passphrase), meaning=_resolve_meaning(meaning))
end

"""
    sign_item(id::Int; passphrase, meaning) -> Dict

Cryptographically sign an item (resource). See [`sign_experiment`](@ref).
"""
function sign_item(id::Int;
    passphrase::AbstractString,
    meaning::Union{Integer, Symbol},
)
    _patch_action(:items, id, "sign";
        passphrase=String(passphrase), meaning=_resolve_meaning(meaning))
end
