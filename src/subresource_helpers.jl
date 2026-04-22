# Generic sub-resource helpers for eLabFTW API v2
#
# Tags, uploads, steps, and links follow the same REST patterns
# across experiments and items. These helpers accept entity_type.

# =============================================================================
# Tags
# =============================================================================

function _tag_entity(entity_type::String, id::Int, tag::String)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/tags"
    _elabftw_post(url, Dict("tag" => tag))
    return nothing
end

function _tag_entity(entity_type::String, id::Int, tags::Vector{String})
    for tag in tags
        _tag_entity(entity_type, id, tag)
    end
    return nothing
end

function _untag_entity(entity_type::String, id::Int, tag_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/tags/$tag_id"
    _elabftw_patch(url, Dict("action" => "unreference"))
    return nothing
end

function _list_entity_tags(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/tags"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _clear_entity_tags(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/tags"
    _elabftw_delete(url)
    return nothing
end

# =============================================================================
# Uploads
# =============================================================================

function _upload_to_entity(entity_type::String, id::Int, filepath::String; comment::String="")
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads"
    response = _elabftw_upload(url, filepath; comment=comment)
    return _parse_id_from_response(response)
end

function _list_entity_uploads(entity_type::String, id::Int;
    state::Union{Int, Vector{Int}, Nothing}=nothing,
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads"
    if !isnothing(state)
        url *= "?state=" * (state isa Int ? string(state) : join(state, ","))
    end
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _get_entity_upload(entity_type::String, id::Int, upload_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads/$upload_id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _update_entity_upload(entity_type::String, id::Int, upload_id::Int;
    real_name::Union{String, Nothing}=nothing,
    comment::Union{String, Nothing}=nothing,
    state::Union{Int, Nothing}=nothing,
)
    _check_enabled()
    all(isnothing, (real_name, comment, state)) &&
        throw(ArgumentError("update_*_upload: specify at least one of real_name, comment, state"))
    isnothing(state) || state in (1, 2, 3) ||
        throw(ArgumentError("update_*_upload: state must be 1 (Normal), 2 (Archived), or 3 (Deleted)"))
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads/$upload_id"
    payload = Dict{String, Any}("action" => "update")
    isnothing(real_name) || (payload["real_name"] = real_name)
    isnothing(comment) || (payload["comment"] = comment)
    isnothing(state) || (payload["state"] = state)
    response = _elabftw_patch(url, payload)
    return JSON.parse(String(response.body))
end

function _replace_entity_upload(entity_type::String, id::Int, upload_id::Int,
    filepath::String; comment::String="",
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads/$upload_id"
    response = _elabftw_upload(url, filepath; comment=comment)
    return _parse_id_from_response(response)
end

function _delete_entity_upload(entity_type::String, id::Int, upload_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads/$upload_id"
    _elabftw_delete(url)
    return nothing
end

# =============================================================================
# Steps
# =============================================================================

function _add_entity_step(entity_type::String, id::Int, body::String)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/steps"
    response = _elabftw_post(url, Dict("body" => body))
    return _parse_id_from_response(response)
end

function _list_entity_steps(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/steps"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _finish_entity_step(entity_type::String, id::Int, step_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/steps/$step_id"
    _elabftw_patch(url, Dict("finished" => true))
    return nothing
end

# =============================================================================
# Links
# =============================================================================

function _link_entity(entity_type::String, id::Int, target_type::String, target_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/$(target_type)_links/$target_id"
    _elabftw_post(url, Dict{String, Any}())
    return nothing
end

function _list_entity_links(entity_type::String, id::Int, target_type::String)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/$(target_type)_links"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _unlink_entity(entity_type::String, id::Int, target_type::String, target_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/$(target_type)_links/$target_id"
    _elabftw_delete(url)
    return nothing
end
