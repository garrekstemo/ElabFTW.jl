# Booking/scheduler events

"""
    list_events(; limit=20, offset=0) -> Vector{Dict}

List scheduler events (bookings).

# Example
```julia
events = list_events()
for e in events
    println(e["id"], ": ", e["title"], " (", e["start"], ")")
end
```
"""
function list_events(; limit::Int=20, offset::Int=0)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/events?limit=$limit&offset=$offset"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_event(; item, title, start, end_) -> Int

Book a scheduler event against a bookable item. Returns the new event ID.

# Arguments
- `item::Int` — ID of the bookable item being reserved (required)
- `title::String` — Event title
- `start::String` — Start datetime (`"YYYY-MM-DD HH:MM:SS"`, ISO 8601 also accepted)
- `end_::String` — End datetime (same format)

# Example
```julia
id = create_event(item=7, title="FTIR session", start="2026-03-01 09:00:00", end_="2026-03-01 12:00:00")
```
"""
function create_event(;
    item::Int,
    title::String,
    start::String,
    end_::String
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/events/$item"
    payload = Dict{String, Any}(
        "title" => title,
        "start" => start,
        "end" => end_
    )
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    get_event(id::Int) -> Dict

Retrieve a scheduler event by ID.
"""
function get_event(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/event/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    update_event(id; title, start, end_, experiment, item_link)

Update a scheduler event. The eLabFTW PATCH contract is target-based, so one
API call is issued per provided field.

# Keyword arguments
- `title::String` — New event title.
- `start::String`, `end_::String` — Reschedule the slot. Both must be provided
  together (the API requires it); format `"YYYY-MM-DD HH:MM:SS"`.
- `experiment::Int` — Bind the booking to an experiment ID.
- `item_link::Int` — Bind the booking to an item (linked resource) ID.

# Example
```julia
update_event(42; title="Rescheduled session")
update_event(42; start="2026-03-02 09:00:00", end_="2026-03-02 11:00:00")
update_event(42; experiment=17)
```
"""
function update_event(id::Int;
    title::Union{String, Nothing}=nothing,
    start::Union{String, Nothing}=nothing,
    end_::Union{String, Nothing}=nothing,
    experiment::Union{Int, Nothing}=nothing,
    item_link::Union{Int, Nothing}=nothing,
)
    _check_enabled()
    if isnothing(start) != isnothing(end_)
        error("update_event: start and end_ must be provided together")
    end
    url = "$(_elabftw_config.url)/api/v2/event/$id"
    if !isnothing(title)
        _elabftw_patch(url, Dict{String, Any}("target" => "title", "content" => title))
    end
    if !isnothing(start)
        _elabftw_patch(url, Dict{String, Any}(
            "target" => "datetime", "start" => start, "end" => end_))
    end
    if !isnothing(experiment)
        _elabftw_patch(url, Dict{String, Any}("target" => "experiment", "id" => experiment))
    end
    if !isnothing(item_link)
        _elabftw_patch(url, Dict{String, Any}("target" => "item_link", "id" => item_link))
    end
    return nothing
end

"""
    delete_event(id::Int)

Delete a scheduler event.
"""
function delete_event(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/event/$id"
    _elabftw_delete(url)
    return nothing
end
