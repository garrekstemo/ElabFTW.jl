# Compound CRUD and linking

"""
    list_compounds(; limit=20, offset=0) -> Vector{Dict}

List compounds in eLabFTW.

# Example
```julia
compounds = list_compounds()
```
"""
function list_compounds(; limit::Int=20, offset::Int=0)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds?limit=$limit&offset=$offset"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_compound(; name, kwargs...) -> Int

Create a new compound. Returns the compound ID. `name` is required; every
other field from the eLabFTW compound schema is accepted as a keyword
argument and forwarded verbatim.

Commonly used:

- Identifiers — `cas_number`, `smiles`, `inchi`, `inchi_key`, `iupac_name`,
  `molecular_formula`, `pubchem_cid::Int`
- Hazard flags (`0` or `1`) — `is_corrosive`, `is_explosive`, `is_flammable`,
  `is_gas_under_pressure`, `is_hazardous2env`, `is_hazardous2health`,
  `is_oxidising`, `is_radioactive`, `is_serious_health_hazard`, `is_toxic`

See [`update_compound`](@ref) for the full writable field set.

# Example
```julia
id = create_compound(name="NH4SCN", cas_number="1762-95-4")
id = create_compound(name="Benzene", cas_number="71-43-2",
                     is_flammable=1, is_toxic=1, is_hazardous2health=1)
```

To pull metadata straight from PubChem, use [`import_compound`](@ref).
"""
function create_compound(; name::AbstractString, kwargs...)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds"
    payload = Dict{String, Any}("name" => String(name))
    for (k, v) in kwargs
        payload[String(k)] = v
    end
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    get_compound(id::Int) -> Dict

Retrieve a compound by ID.
"""
function get_compound(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    update_compound(id::Int; kwargs...) -> Dict

Update a compound's fields. All keyword arguments are forwarded verbatim
to the server — there are ~30 accepted fields so an open interface is
more practical than a full kwarg enumeration.

Commonly updated fields:
- `name::String`, `cas_number::String`, `smiles::String`, `inchi::String`
- `inchi_key::String`, `iupac_name::String`, `molecular_formula::String`
- `pubchem_cid::Int`
- Hazard flags (`0` or `1`): `is_corrosive`, `is_flammable`, `is_toxic`,
  `is_explosive`, `is_oxidising`, `is_radioactive`, `is_hazardous2env`,
  `is_hazardous2health`, `is_serious_health_hazard`, ...

Returns the updated compound record.

!!! note
    The OpenAPI spec does not document PATCH on `/compounds/{id}`, but the
    server accepts it. This function may break if eLabFTW later removes the
    endpoint.

# Example
```julia
update_compound(42; name="Caffeine (verified)", is_toxic=1)
```
"""
function update_compound(id::Int; kwargs...)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds/$id"
    payload = Dict{String, Any}(String(k) => v for (k, v) in kwargs)
    isempty(payload) && return get_compound(id)
    response = _elabftw_patch(url, payload)
    return JSON.parse(String(response.body))
end

"""
    import_compound(; cas=nothing, cid=nothing) -> Int

Import a compound from PubChem by CAS registry number or PubChem CID.
Returns the compound ID — either a new record, or an existing one if a
compound with the same CAS or CID is already in the database (the server
returns 201 in both cases).

Exactly one of `cas` or `cid` must be provided. If both are given, the
server silently prefers `cid`.

# Example
```julia
caffeine = import_compound(cas="58-08-2")
aspirin  = import_compound(cid=2244)
```

# Throws
- `ArgumentError` — neither or both of `cas` / `cid` were provided.
"""
function import_compound(;
    cas::Union{AbstractString, Nothing}=nothing,
    cid::Union{Integer, Nothing}=nothing,
)
    _check_enabled()
    isnothing(cas) == isnothing(cid) &&
        throw(ArgumentError("import_compound: specify exactly one of `cas` or `cid`"))
    url = "$(_elabftw_config.url)/api/v2/compounds"
    payload = Dict{String, Any}("action" => "duplicate")
    isnothing(cas) || (payload["cas"] = String(cas))
    isnothing(cid) || (payload["cid"] = Int(cid))
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    delete_compound(id::Int)

Delete a compound.
"""
function delete_compound(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds/$id"
    _elabftw_delete(url)
    return nothing
end

"""
    link_compound(entity_type::Symbol, entity_id::Int, compound_id::Int)

Link a compound to an experiment or item.

`entity_type` is `:experiments` or `:items`.

# Example
```julia
link_compound(:experiments, 42, 7)
```
"""
function link_compound(entity_type::Symbol, entity_id::Int, compound_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/compounds/$compound_id"
    _elabftw_post(url, Dict{String, Any}())
    return nothing
end

"""
    list_compound_links(entity_type::Symbol, entity_id::Int) -> Vector{Dict}

List compounds linked to an experiment or item.

# Example
```julia
compounds = list_compound_links(:experiments, 42)
```
"""
function list_compound_links(entity_type::Symbol, entity_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/compounds"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end
