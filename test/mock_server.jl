# Mock HTTP server for ElabFTW.jl tests
# Provides a stateful in-memory server that mimics the eLabFTW API v2.

mutable struct MockState
    next_id::Int
    collections::Dict{String, Dict{Int, Dict{String, Any}}}
    team_tags::Dict{Int, Dict{String, Any}}
    favorite_tags::Vector{Dict{String, Any}}
    storage_units::Dict{Int, Dict{String, Any}}
    containers::Dict{Int, Dict{String, Any}}
    # Controlled failure injection for retry tests: each entry is a queue of
    # statuses to return on the next N requests to that path. Depleting the
    # queue drops through to normal routing. "Retry-After" is attached to 429s.
    inject_failures::Vector{@NamedTuple{path::String, status::Int, retry_after::Union{Int, Nothing}}}
end

function MockState()
    MockState(
        1,
        Dict(
            "experiments" => Dict{Int, Dict{String, Any}}(),
            "items" => Dict{Int, Dict{String, Any}}(),
            "experiments_templates" => Dict{Int, Dict{String, Any}}(),
            "items_types" => Dict{Int, Dict{String, Any}}(),
            "events" => Dict{Int, Dict{String, Any}}(),
            "compounds" => Dict{Int, Dict{String, Any}}(),
        ),
        Dict{Int, Dict{String, Any}}(),
        Dict{String, Any}[],
        Dict{Int, Dict{String, Any}}(),
        Dict{Int, Dict{String, Any}}(),
        @NamedTuple{path::String, status::Int, retry_after::Union{Int, Nothing}}[]
    )
end

function queue_failure!(state::MockState, path::String, status::Int;
                       retry_after::Union{Int, Nothing}=nothing)
    push!(state.inject_failures, (path=path, status=status, retry_after=retry_after))
    return nothing
end

function storage_unit_full_path(state::MockState, unit::Dict)
    parts = String[String(unit["name"])]
    pid = unit["parent_id"]
    while !isnothing(pid)
        parent = get(state.storage_units, pid, nothing)
        isnothing(parent) && break
        pushfirst!(parts, String(parent["name"]))
        pid = parent["parent_id"]
    end
    return join(parts, " > ")
end

function storage_unit_depth(state::MockState, unit::Dict)
    depth = 0
    pid = unit["parent_id"]
    while !isnothing(pid)
        parent = get(state.storage_units, pid, nothing)
        isnothing(parent) && break
        depth += 1
        pid = parent["parent_id"]
    end
    return depth
end

function storage_unit_view(state::MockState, unit::Dict; include_children::Bool=false)
    view = Dict{String, Any}(
        "id" => unit["id"],
        "name" => unit["name"],
        "parent_id" => unit["parent_id"],
        "full_path" => storage_unit_full_path(state, unit),
        "level_depth" => storage_unit_depth(state, unit),
    )
    if include_children
        view["children_count"] =
            count(u -> u["parent_id"] == unit["id"], values(state.storage_units))
    end
    return view
end

function new_id!(state::MockState)
    id = state.next_id
    state.next_id += 1
    return id
end

function json_response(data; status=200)
    body = JSON.json(data)
    resp = HTTP.Response(status, body)
    push!(resp.headers, "Content-Type" => "application/json")
    return resp
end

function created_response(location::String)
    resp = HTTP.Response(201, "")
    push!(resp.headers, "Location" => location)
    return resp
end

ok_response() = HTTP.Response(200, "")
not_found() = HTTP.Response(404, "Not Found")

function parse_query(target::String)
    parts = split(target, "?"; limit=2)
    length(parts) < 2 && return Dict{String, String}()
    params = Dict{String, String}()
    for param in split(parts[2], "&")
        kv = split(param, "="; limit=2)
        length(kv) == 2 && (params[String(kv[1])] = HTTP.unescapeuri(String(kv[2])))
    end
    return params
end

function parse_json_body(req::HTTP.Request)
    isempty(req.body) && return Dict{String, Any}()
    ct = HTTP.header(req, "Content-Type", "")
    startswith(ct, "multipart/") && return Dict{String, Any}()
    try
        parsed = JSON.parse(String(copy(req.body)))
        return Dict{String, Any}(parsed)
    catch
        return Dict{String, Any}()
    end
end

function apply_action!(entity::Dict, data::Dict)
    action = get(data, "action", "")
    if action == "lock"
        # Toggle locked state (matches real server behavior).
        entity["locked"] = get(entity, "locked", 0) == 1 ? 0 : 1
        return json_response(entity)
    elseif action == "pin"
        entity["is_pinned"] = get(entity, "is_pinned", 0) == 1 ? 0 : 1
        return json_response(entity)
    elseif action == "timestamp"
        entity["timestamped"] = 1
        entity["timestamped_at"] = "2026-01-01 00:00:00"
        return json_response(entity)
    elseif action == "sign"
        # Real server returns 500 when signing keys are not configured.
        # Mock the success path only when both passphrase and meaning are
        # present; otherwise mirror the server's 500.
        haskey(data, "passphrase") && haskey(data, "meaning") || return HTTP.Response(500, "signing keys not configured")
        entity["signed"] = 1
        entity["meaning"] = data["meaning"]
        return json_response(entity)
    end
    return HTTP.Response(400, "unknown action: $action")
end

function create_entity!(state::MockState, collection::String, data::Dict)
    id = new_id!(state)
    entity = Dict{String, Any}(
        "id" => id,
        "title" => get(data, "title", "Untitled"),
        "body" => get(data, "body", ""),
        "date" => "2026-01-01T00:00:00",
        "tags" => Any[],
        "steps" => Any[],
        "uploads" => Any[],
        "comments" => Any[],
        "experiments_links" => Any[],
        "items_links" => Any[],
        "compounds" => Any[],
        "category" => get(data, "category", nothing),
        "category_title" => get(data, "category_title", ""),
        "metadata" => get(data, "metadata", nothing),
        "locked" => 0,
        "is_pinned" => 0,
        "timestamped" => 0,
    )
    for key in ("start", "end", "name", "cas_number", "smiles", "molecular_formula",
                "content_type", "item", "state", "userid")
        haskey(data, key) && (entity[key] = data[key])
    end
    state.collections[collection][id] = entity
    return id
end

function mock_handler(state::MockState)
    return function(req::HTTP.Request)
        method = req.method
        path = String(split(req.target, "?")[1])
        segments = filter(!isempty, split(path, "/"))

        if length(segments) < 3 || segments[1] != "api" || segments[2] != "v2"
            return not_found()
        end

        rest = String.(segments[3:end])

        injected = maybe_inject(state, path)
        isnothing(injected) || return injected

        try
            return route(state, method, rest, req)
        catch e
            @error "Mock server error" exception=(e, catch_backtrace())
            return HTTP.Response(500, "Internal Server Error")
        end
    end
end

function maybe_inject(state::MockState, path::String)
    isempty(state.inject_failures) && return nothing
    idx = findfirst(f -> f.path == path, state.inject_failures)
    isnothing(idx) && return nothing
    f = state.inject_failures[idx]
    deleteat!(state.inject_failures, idx)
    resp = HTTP.Response(f.status, "injected")
    isnothing(f.retry_after) || push!(resp.headers, "Retry-After" => string(f.retry_after))
    return resp
end

function route(state::MockState, method::String, rest::Vector{String}, req::HTTP.Request)
    n = length(rest)

    # /api/v2/info
    if n == 1 && rest[1] == "info" && method == "GET"
        return json_response(Dict("elabftw_version" => "5.0.0-mock"))
    end

    # /api/v2/import
    if n == 1 && rest[1] == "import" && method == "POST"
        id = new_id!(state)
        state.collections["experiments"][id] = Dict{String, Any}(
            "id" => id, "title" => "Imported", "body" => "", "date" => "2026-01-01T00:00:00",
            "tags" => Any[], "steps" => Any[], "uploads" => Any[], "comments" => Any[],
            "experiments_links" => Any[], "items_links" => Any[], "compounds" => Any[],
            "category" => nothing, "category_title" => "", "metadata" => nothing,
        )
        return created_response("/api/v2/experiments/$id")
    end

    # /api/v2/favtags[/{id}]
    if n >= 1 && rest[1] == "favtags"
        return route_favtags(state, method, rest[2:end], req)
    end

    # /api/v2/event/{id} — singular, per spec
    if n == 2 && rest[1] == "event"
        return route_event_single(state, method, rest[2], req)
    end

    # /api/v2/events/{item_id} — POST books an item; other verbs on this path 404
    # (single-event ops live at /event/{id}, handled above)
    if n == 2 && rest[1] == "events"
        if method == "POST"
            item_id = tryparse(Int, rest[2])
            isnothing(item_id) && return not_found()
            data = parse_json_body(req)
            data["item"] = item_id
            id = create_entity!(state, "events", data)
            return created_response("/api/v2/event/$id")
        end
        return not_found()
    end

    # /api/v2/users/me[/...]
    if n >= 2 && rest[1] == "users" && rest[2] == "me"
        return route_users_me(state, method, rest[3:end], req)
    end

    # /api/v2/teams/current/...
    if n >= 3 && rest[1] == "teams" && rest[2] == "current"
        return route_teams(state, method, rest[3:end], req)
    end

    # /api/v2/storage_units[/{id}]
    if n >= 1 && rest[1] == "storage_units"
        return route_storage_units(state, method, rest[2:end], req)
    end

    # Entity collections
    collection = rest[1]
    col = get(state.collections, collection, nothing)
    isnothing(col) && return not_found()

    if n == 1
        if method == "GET"
            params = parse_query(req.target)
            limit = parse(Int, get(params, "limit", "20"))
            offset = parse(Int, get(params, "offset", "0"))
            query = get(params, "q", nothing)
            entities = collect(values(col))
            state_filter = parse(Int, get(params, "state", "1"))
            entities = filter(e -> get(e, "state", 1) == state_filter, entities)
            if haskey(params, "cat")
                cats = Set(parse.(Int, split(params["cat"], ",")))
                entities = filter(e -> get(e, "category", nothing) in cats, entities)
            end
            if haskey(params, "owner")
                owners = Set(parse.(Int, split(params["owner"], ",")))
                entities = filter(e -> get(e, "userid", nothing) in owners, entities)
            end
            if !isnothing(query) && !isempty(query)
                q_lower = lowercase(query)
                entities = filter(e -> occursin(q_lower, lowercase(get(e, "title", ""))), entities)
            end
            sort!(entities; by=e -> e["id"], rev=true)
            start_idx = offset + 1
            end_idx = min(offset + limit, length(entities))
            result = start_idx <= length(entities) ? entities[start_idx:end_idx] : Dict{String, Any}[]
            return json_response(result)
        elseif method == "POST"
            data = parse_json_body(req)
            id = create_entity!(state, collection, data)
            return created_response("/api/v2/$collection/$id")
        end
    elseif n == 2
        id = tryparse(Int, rest[2])
        isnothing(id) && return not_found()

        if method == "GET"
            entity = get(col, id, nothing)
            isnothing(entity) && return not_found()
            return json_response(entity)
        elseif method == "PATCH"
            entity = get(col, id, nothing)
            isnothing(entity) && return not_found()
            data = parse_json_body(req)
            if haskey(data, "action")
                return apply_action!(entity, data)
            end
            # Snapshot a revision whenever `body` is being replaced with a
            # different value — matches the real server's "on meaningful edit"
            # behavior without trying to emulate min_days/min_delta config.
            if haskey(data, "body") && get(entity, "body", "") != data["body"]
                revs = get!(entity, "revisions", Dict{Int, Dict{String, Any}}())
                rev_id = new_id!(state)
                revs[rev_id] = Dict{String, Any}(
                    "id" => rev_id,
                    "body" => get(entity, "body", ""),
                    "body_html" => get(entity, "body", ""),
                    "content_type" => 1,
                    "created_at" => "2026-01-01 00:00:00",
                    "fullname" => "Test User",
                    "userid" => 1,
                )
            end
            for (k, v) in data
                entity[k] = v
            end
            return ok_response()
        elseif method == "DELETE"
            haskey(col, id) || return not_found()
            delete!(col, id)
            return ok_response()
        elseif method == "POST"
            data = parse_json_body(req)
            if get(data, "action", "") == "duplicate"
                entity = get(col, id, nothing)
                isnothing(entity) && return not_found()
                new_id = create_entity!(state, collection, copy(entity))
                return created_response("/api/v2/$collection/$new_id")
            end
            return HTTP.Response(400, "Bad Request")
        end
    elseif n >= 3
        id = tryparse(Int, rest[2])
        isnothing(id) && return not_found()
        entity = get(col, id, nothing)
        isnothing(entity) && return not_found()
        return route_subresource(state, method, entity, collection, id, rest[3], rest[4:end], req)
    end

    return not_found()
end

function route_users_me(state::MockState, method::String, rest::Vector{String}, req::HTTP.Request)
    n = length(rest)

    if n == 0 && method == "GET"
        return json_response(Dict("fullname" => "Test User", "email" => "test@example.com"))
    end

    return not_found()
end

function route_favtags(state::MockState, method::String, rest::Vector{String}, req::HTTP.Request)
    n = length(rest)

    if n == 0
        if method == "GET"
            return json_response(state.favorite_tags)
        elseif method == "POST"
            data = parse_json_body(req)
            tag = get(data, "tag", "")
            isempty(tag) && return HTTP.Response(400, "tag required")
            tags_id = new_id!(state)
            push!(state.favorite_tags, Dict{String, Any}(
                "users_id" => 1, "tags_id" => tags_id, "tag" => tag
            ))
            return created_response("/api/v2/favtags/$tags_id")
        end
    elseif n == 1
        tags_id = tryparse(Int, rest[1])
        isnothing(tags_id) && return not_found()
        if method == "DELETE"
            filter!(t -> t["tags_id"] != tags_id, state.favorite_tags)
            return ok_response()
        end
    end

    return not_found()
end

function route_event_single(state::MockState, method::String, id_str::String, req::HTTP.Request)
    id = tryparse(Int, id_str)
    isnothing(id) && return not_found()
    col = state.collections["events"]
    entity = get(col, id, nothing)
    isnothing(entity) && return not_found()

    if method == "GET"
        return json_response(entity)
    elseif method == "PATCH"
        data = parse_json_body(req)
        target = get(data, "target", nothing)
        isnothing(target) && return HTTP.Response(400, "Incorrect target parameter.")
        if target == "title"
            entity["title"] = get(data, "content", "")
        elseif target == "datetime"
            (haskey(data, "start") && haskey(data, "end")) ||
                return HTTP.Response(400, "Missing required parameter(s): start, end.")
            entity["start"] = data["start"]
            entity["end"] = data["end"]
        elseif target == "experiment"
            entity["experiment"] = get(data, "id", nothing)
        elseif target == "item_link"
            entity["item_link"] = get(data, "id", nothing)
        else
            return HTTP.Response(400, "Incorrect target parameter.")
        end
        return ok_response()
    elseif method == "DELETE"
        delete!(col, id)
        return ok_response()
    end

    return not_found()
end

function route_teams(state::MockState, method::String, rest::Vector{String}, req::HTTP.Request)
    n = length(rest)

    if n == 1
        resource = rest[1]
        if method == "GET"
            if resource == "tags"
                tags = [Dict{String, Any}("id" => id, "tag" => t["tag"],
                    "item_count" => get(t, "item_count", 0), "is_favorite" => 0, "team" => 1)
                    for (id, t) in state.team_tags]
                return json_response(tags)
            elseif resource == "experiments_categories"
                return json_response([
                    Dict("id" => 1, "title" => "Default", "color" => "#3498db", "is_default" => 1)
                ])
            elseif resource == "resources_categories"
                return json_response([
                    Dict("id" => 1, "title" => "General", "color" => "#2ecc71", "is_default" => 1)
                ])
            end
        end
    elseif n == 2
        resource = rest[1]
        sub_id = tryparse(Int, rest[2])
        isnothing(sub_id) && return not_found()

        if resource == "tags"
            if method == "PATCH"
                tag = get(state.team_tags, sub_id, nothing)
                isnothing(tag) && return not_found()
                data = parse_json_body(req)
                haskey(data, "tag") && (tag["tag"] = data["tag"])
                return ok_response()
            elseif method == "DELETE"
                haskey(state.team_tags, sub_id) || return not_found()
                delete!(state.team_tags, sub_id)
                return ok_response()
            end
        end
    end

    return not_found()
end

function container_single_view(row::Dict)
    return Dict{String, Any}(
        "id" => row["id"],
        "qty_stored" => row["qty_stored"],
        "qty_unit" => row["qty_unit"],
        "storage_id" => row["storage_id"],
        "item_id" => row["entity_id"],
    )
end

function container_list_view(state::MockState, row::Dict)
    unit = get(state.storage_units, row["storage_id"], nothing)
    view = container_single_view(row)
    view["storage_name"] = isnothing(unit) ? "" : unit["name"]
    view["full_path"] = isnothing(unit) ? "" : storage_unit_full_path(state, unit)
    return view
end

function container_assignment_view(state::MockState, row::Dict)
    etype = row["entity_type"]
    entity_id = row["entity_id"]
    entity = get(get(state.collections, etype, Dict{Int, Dict{String, Any}}()), entity_id, nothing)
    unit = get(state.storage_units, row["storage_id"], nothing)
    return Dict{String, Any}(
        "entity_id" => entity_id,
        "entity_title" => isnothing(entity) ? "" : get(entity, "title", ""),
        "page" => etype == "experiments" ? "experiments" : "database",
        "container2item_id" => row["id"],
        "qty_stored" => row["qty_stored"],
        "qty_unit" => row["qty_unit"],
        "storage_id" => row["storage_id"],
        "storage_name" => isnothing(unit) ? "" : unit["name"],
        "full_path" => isnothing(unit) ? "" : storage_unit_full_path(state, unit),
    )
end

function route_storage_units(state::MockState, method::String, rest::Vector{String}, req::HTTP.Request)
    n = length(rest)

    if n == 0
        if method == "GET"
            params = parse_query(req.target)
            if get(params, "hierarchy", "") == "true"
                units = [storage_unit_view(state, u; include_children=true)
                         for u in values(state.storage_units)]
                sort!(units; by=u -> u["id"])
                return json_response(units)
            end
            rows = [container_assignment_view(state, c) for c in values(state.containers)]
            sort!(rows; by=r -> r["container2item_id"])
            return json_response(rows)
        elseif method == "POST"
            data = parse_json_body(req)
            name = String(get(data, "name", ""))
            isempty(name) && return HTTP.Response(400, "Name must not be empty!")
            id = new_id!(state)
            state.storage_units[id] = Dict{String, Any}(
                "id" => id, "name" => name,
                "parent_id" => get(data, "parent_id", nothing),
            )
            return created_response("/api/v2/storage_units/$id")
        end
    elseif n == 1
        id = tryparse(Int, rest[1])
        isnothing(id) && return not_found()
        unit = get(state.storage_units, id, nothing)
        if method == "GET"
            isnothing(unit) && return not_found()
            return json_response(storage_unit_view(state, unit))
        elseif method == "PATCH"
            isnothing(unit) && return not_found()
            data = parse_json_body(req)
            name = String(get(data, "name", ""))
            isempty(name) && return HTTP.Response(400, "Name must not be empty!")
            unit["name"] = name
            return json_response(storage_unit_view(state, unit))
        elseif method == "DELETE"
            isnothing(unit) && return not_found()
            any(u -> u["parent_id"] == id, values(state.storage_units)) &&
                return HTTP.Response(422, "has children")
            any(c -> c["storage_id"] == id, values(state.containers)) &&
                return HTTP.Response(422, "has containers")
            delete!(state.storage_units, id)
            return HTTP.Response(204, "")
        end
    end

    return not_found()
end

function route_subresource(state::MockState, method::String, entity::Dict, collection::String,
    entity_id::Int, subresource::String, rest::Vector{String}, req::HTTP.Request)
    n = length(rest)

    # Tags
    if subresource == "tags"
        tags = entity["tags"]::Vector{Any}
        if n == 0
            method == "GET" && return json_response(tags)
            if method == "POST"
                data = parse_json_body(req)
                tag_name = get(data, "tag", "")
                tag_id = new_id!(state)
                push!(tags, Dict{String, Any}("tag_id" => tag_id, "tag" => tag_name))
                if !haskey(state.team_tags, tag_id)
                    state.team_tags[tag_id] = Dict{String, Any}("tag" => tag_name, "item_count" => 1)
                end
                return created_response("/api/v2/$collection/$entity_id/tags/$tag_id")
            end
            method == "DELETE" && (empty!(tags); return ok_response())
        elseif n == 1
            tag_id = tryparse(Int, rest[1])
            isnothing(tag_id) && return not_found()
            if method == "PATCH"
                filter!(t -> get(t, "tag_id", -1) != tag_id, tags)
                return ok_response()
            end
        end
        return not_found()
    end

    # Steps
    if subresource == "steps"
        steps = entity["steps"]::Vector{Any}
        if n == 0
            method == "GET" && return json_response(steps)
            if method == "POST"
                data = parse_json_body(req)
                step_id = new_id!(state)
                push!(steps, Dict{String, Any}("id" => step_id, "body" => get(data, "body", ""), "finished" => false))
                return created_response("/api/v2/$collection/$entity_id/steps/$step_id")
            end
        elseif n == 1
            step_id = tryparse(Int, rest[1])
            isnothing(step_id) && return not_found()
            if method == "PATCH"
                data = parse_json_body(req)
                for step in steps
                    if step["id"] == step_id
                        get(data, "finished", false) && (step["finished"] = true)
                        break
                    end
                end
                return ok_response()
            end
        end
        return not_found()
    end

    # Uploads
    if subresource == "uploads"
        uploads = entity["uploads"]::Vector{Any}
        if n == 0
            method == "GET" && return json_response(uploads)
            if method == "POST"
                upload_id = new_id!(state)
                push!(uploads, Dict{String, Any}("id" => upload_id, "real_name" => "test_file.txt", "comment" => ""))
                return created_response("/api/v2/$collection/$entity_id/uploads/$upload_id")
            end
        elseif n == 1
            upload_id = tryparse(Int, rest[1])
            isnothing(upload_id) && return not_found()
            if method == "GET"
                for upload in uploads
                    upload["id"] == upload_id && return json_response(upload)
                end
                return not_found()
            elseif method == "DELETE"
                filter!(u -> u["id"] != upload_id, uploads)
                return ok_response()
            end
        end
        return not_found()
    end

    # Comments
    if subresource == "comments"
        comments = entity["comments"]::Vector{Any}
        if n == 0
            method == "GET" && return json_response(comments)
            if method == "POST"
                data = parse_json_body(req)
                comment_id = new_id!(state)
                push!(comments, Dict{String, Any}("id" => comment_id, "comment" => get(data, "comment", "")))
                return created_response("/api/v2/$collection/$entity_id/comments/$comment_id")
            end
        elseif n == 1
            comment_id = tryparse(Int, rest[1])
            isnothing(comment_id) && return not_found()
            if method == "GET"
                for c in comments
                    c["id"] == comment_id && return json_response(c)
                end
                return not_found()
            elseif method == "PATCH"
                data = parse_json_body(req)
                for c in comments
                    if c["id"] == comment_id
                        haskey(data, "comment") && (c["comment"] = data["comment"])
                        break
                    end
                end
                return ok_response()
            elseif method == "DELETE"
                filter!(c -> c["id"] != comment_id, comments)
                return ok_response()
            end
        end
        return not_found()
    end

    # Revisions (body history)
    if subresource == "revisions"
        revs = get!(entity, "revisions", Dict{Int, Dict{String, Any}}())
        if n == 0 && method == "GET"
            summary = [Dict{String, Any}(
                "id" => r["id"],
                "content_type" => r["content_type"],
                "created_at" => r["created_at"],
                "fullname" => r["fullname"],
            ) for r in values(revs)]
            sort!(summary; by=r -> r["id"], rev=true)
            return json_response(summary)
        elseif n == 1
            rev_id = tryparse(Int, rest[1])
            isnothing(rev_id) && return not_found()
            rev = get(revs, rev_id, nothing)
            isnothing(rev) && return not_found()
            if method == "GET"
                return json_response(rev)
            elseif method == "PATCH"
                data = parse_json_body(req)
                get(data, "action", "") == "replace" ||
                    return HTTP.Response(400, "only action=replace is supported")
                entity["body"] = rev["body"]
                return json_response(rev)
            end
        end
        return not_found()
    end

    # Compounds (as subresource on experiments/items)
    if subresource == "compounds"
        compounds = entity["compounds"]::Vector{Any}
        if n == 0 && method == "GET"
            return json_response(compounds)
        elseif n == 1
            compound_id = tryparse(Int, rest[1])
            isnothing(compound_id) && return not_found()
            if method == "POST"
                push!(compounds, Dict{String, Any}("id" => compound_id))
                return created_response("/api/v2/$collection/$entity_id/compounds/$compound_id")
            end
        end
        return not_found()
    end

    # Containers (storage assignments)
    if subresource == "containers"
        etype = collection
        if n == 0 && method == "GET"
            rows = [container_list_view(state, c) for c in values(state.containers)
                    if c["entity_type"] == etype && c["entity_id"] == entity_id]
            sort!(rows; by=r -> r["id"])
            return json_response(rows)
        elseif n == 1
            subid = tryparse(Int, rest[1])
            isnothing(subid) && return not_found()
            if method == "POST"
                data = parse_json_body(req)
                storage_id = subid
                haskey(state.storage_units, storage_id) ||
                    return HTTP.Response(400, "storage unit not found")
                qty_stored = get(data, "qty_stored", nothing)
                isnothing(qty_stored) && return HTTP.Response(400, "qty_stored required")
                qty_unit = String(get(data, "qty_unit", ""))
                length(qty_unit) > 10 && (qty_unit = qty_unit[1:10])
                row_id = new_id!(state)
                state.containers[row_id] = Dict{String, Any}(
                    "id" => row_id,
                    "entity_type" => etype,
                    "entity_id" => entity_id,
                    "storage_id" => storage_id,
                    "qty_stored" => string(qty_stored),
                    "qty_unit" => qty_unit,
                )
                return created_response("/api/v2/$etype/$entity_id/containers2items/$storage_id")
            elseif method == "GET"
                row = get(state.containers, subid, nothing)
                isnothing(row) && return not_found()
                return json_response(container_single_view(row))
            elseif method == "PATCH"
                row = get(state.containers, subid, nothing)
                isnothing(row) && return not_found()
                data = parse_json_body(req)
                haskey(data, "qty_stored") && (row["qty_stored"] = string(data["qty_stored"]))
                if haskey(data, "qty_unit")
                    u = String(data["qty_unit"])
                    length(u) > 10 && (u = u[1:10])
                    row["qty_unit"] = u
                end
                return json_response(container_single_view(row))
            elseif method == "DELETE"
                haskey(state.containers, subid) || return not_found()
                delete!(state.containers, subid)
                return HTTP.Response(204, "")
            end
        end
        return not_found()
    end

    # Links (experiments_links, items_links)
    if endswith(subresource, "_links")
        link_key = subresource
        links = get!(entity, link_key, Any[])::Vector{Any}

        if n == 0 && method == "GET"
            return json_response(links)
        elseif n == 1
            target_id = tryparse(Int, rest[1])
            isnothing(target_id) && return not_found()
            if method == "POST"
                push!(links, Dict{String, Any}("entityid" => target_id, "id" => target_id))
                return created_response("/api/v2/$collection/$entity_id/$subresource/$target_id")
            elseif method == "DELETE"
                filter!(l -> get(l, "entityid", get(l, "id", -1)) != target_id, links)
                return ok_response()
            end
        end
        return not_found()
    end

    # Exports
    if subresource == "exports" && n == 1 && method == "GET"
        resp = HTTP.Response(200, Vector{UInt8}("mock export data"))
        push!(resp.headers, "Content-Type" => "application/octet-stream")
        return resp
    end

    return not_found()
end

function find_free_port()
    s = Sockets.listen(Sockets.IPv4("127.0.0.1"), 0)
    port = Int(Sockets.getsockname(s)[2])
    close(s)
    return port
end

function start_mock_server()
    port = find_free_port()
    state = MockState()
    handler = mock_handler(state)
    server = HTTP.serve!(handler, "127.0.0.1", port)
    sleep(0.3)
    return (server=server, port=port, state=state)
end

function stop_mock_server(server)
    close(server)
end
