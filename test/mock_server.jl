# Mock HTTP server for ElabFTW.jl tests
# Provides a stateful in-memory server that mimics the eLabFTW API v2.

mutable struct MockState
    next_id::Int
    collections::Dict{String, Dict{Int, Dict{String, Any}}}
    team_tags::Dict{Int, Dict{String, Any}}
    favorite_tags::Vector{Dict{String, Any}}
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
        Dict{String, Any}[]
    )
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
    )
    for key in ("start", "end", "name", "cas_number", "smiles", "molecular_formula", "content_type", "item")
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

        try
            return route(state, method, rest, req)
        catch e
            @error "Mock server error" exception=(e, catch_backtrace())
            return HTTP.Response(500, "Internal Server Error")
        end
    end
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

    # /api/v2/users/me[/...]
    if n >= 2 && rest[1] == "users" && rest[2] == "me"
        return route_users_me(state, method, rest[3:end], req)
    end

    # /api/v2/teams/current/...
    if n >= 3 && rest[1] == "teams" && rest[2] == "current"
        return route_teams(state, method, rest[3:end], req)
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

    if n >= 1 && rest[1] == "favorite_tags"
        if n == 1
            if method == "GET"
                return json_response(state.favorite_tags)
            end
        elseif n == 2
            tag_id = tryparse(Int, rest[2])
            isnothing(tag_id) && return not_found()
            if method == "POST"
                push!(state.favorite_tags, Dict{String, Any}("id" => tag_id, "tag" => "tag_$tag_id"))
                return created_response("/api/v2/users/me/favorite_tags/$tag_id")
            elseif method == "DELETE"
                filter!(t -> t["id"] != tag_id, state.favorite_tags)
                return ok_response()
            end
        end
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
