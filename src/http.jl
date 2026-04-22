# Internal HTTP helpers for eLabFTW API v2.
#
# Handles authentication headers, typed errors, and retry-with-backoff for
# transient failures (5xx + 429). Each public module (experiments.jl, items.jl,
# etc.) calls into the `_elabftw_*` helpers, never HTTP.jl directly.

function _check_enabled()
    elabftw_enabled() || throw(NotConfiguredError())
end

function _parse_id_from_response(response)::Int
    location = HTTP.header(response, "Location", "")
    if isempty(location)
        body = JSON.parse(String(response.body))
        id = get(body, "id", nothing)
        isnothing(id) &&
            throw(ParseError("no ID in response (no Location header or body id)"))
        return Int(id)
    end
    id_str = last(split(location, "/"))
    parsed = tryparse(Int, String(id_str))
    isnothing(parsed) && throw(ParseError("could not parse ID from Location: $location"))
    return parsed
end

function _parse_retry_after(response)
    raw = HTTP.header(response, "Retry-After", "")
    isempty(raw) && return nothing
    return tryparse(Int, String(raw))
end

function _auth_headers(; content_type::Union{String, Nothing}=nothing,
                        accept::String="application/json")
    headers = Pair{String, String}[
        "Authorization" => _elabftw_config.api_key,
        "Accept" => accept,
    ]
    isnothing(content_type) || push!(headers, "Content-Type" => content_type)
    return headers
end

# Core request runner: applies retry with exponential backoff on transient
# failures. `do_request` is a zero-arg closure that performs the actual HTTP
# call and returns the response (or throws an HTTP.StatusError).
function _run_with_retry(do_request, url::String)
    max_retries = _elabftw_config.max_retries
    base = _elabftw_config.retry_base_delay
    attempt = 0
    last_response = nothing

    while true
        attempt += 1
        try
            return do_request()
        catch e
            if e isa HTTP.ExceptionRequest.StatusError
                status = e.status
                last_response = e.response
                if (status >= 500 || status == 429) && attempt <= max_retries
                    delay = _retry_delay(base, attempt, e.response, status)
                    sleep(delay)
                    continue
                end
                body = _safe_body(e.response)
                err = _http_error(status, url, body)
                if err isa RateLimitError
                    throw(RateLimitError(url, _parse_retry_after(e.response)))
                end
                throw(err)
            elseif e isa HTTP.Exceptions.ConnectError ||
                   e isa HTTP.Exceptions.TimeoutError ||
                   e isa Base.IOError
                throw(NetworkError(sprint(showerror, e), e))
            else
                rethrow(e)
            end
        end
    end
end

function _retry_delay(base::Real, attempt::Integer, response, status::Integer)
    if Int(status) == 429
        ra = _parse_retry_after(response)
        isnothing(ra) || return Float64(ra)
    end
    return base * 2.0^(Int(attempt) - 1)
end

function _safe_body(response)
    try
        return String(copy(response.body))
    catch
        return ""
    end
end

# We disable HTTP.jl's built-in retry (`retry=false`) so our own
# `_run_with_retry` is the only thing in control. Same for redirect
# handling (`redirect=false`) to avoid silent host changes.
const _HTTP_OPTS = (retry=false, redirect=false)

function _elabftw_request(url::String; accept::String="application/json")
    headers = _auth_headers(; accept=accept)
    _run_with_retry(url) do
        HTTP.get(url, headers; _HTTP_OPTS...)
    end
end

function _elabftw_post(url::String, body_dict::Dict)
    headers = _auth_headers(; content_type="application/json")
    body = JSON.json(body_dict)
    _run_with_retry(url) do
        HTTP.post(url, headers, body; _HTTP_OPTS...)
    end
end

function _elabftw_patch(url::String, body_dict::Dict)
    headers = _auth_headers(; content_type="application/json")
    body = JSON.json(body_dict)
    _run_with_retry(url) do
        HTTP.patch(url, headers, body; _HTTP_OPTS...)
    end
end

function _elabftw_delete(url::String)
    headers = _auth_headers()
    _run_with_retry(url) do
        HTTP.delete(url, headers; _HTTP_OPTS...)
    end
end

function _elabftw_upload(url::String, filepath::String; comment::String="")
    isfile(filepath) || throw(ParseError("File not found: $filepath"))
    headers = _auth_headers()
    _run_with_retry(url) do
        io = open(filepath)
        try
            form = HTTP.Form(Dict("file" => io, "comment" => comment))
            HTTP.post(url, headers, form; _HTTP_OPTS...)
        finally
            close(io)
        end
    end
end

"""
    elabftw_http(method, path; body=nothing, query=nothing) -> HTTP.Response

Escape hatch for callers who need access to response headers (e.g. the
`Location` header on a POST, or pagination metadata). Returns the raw
`HTTP.Response` — callers can read `.headers`, `.status`, and `.body`
themselves.

- `method` is `"GET"`, `"POST"`, `"PATCH"`, or `"DELETE"`.
- `path` is the API path without the base URL — e.g. `"/api/v2/experiments"`.
- `body` is a `Dict` serialized as JSON (POST/PATCH only).
- `query` is a `Dict` or `Vector{Pair}` appended as the query string.

Retries and typed errors apply identically to the built-in helpers.

# Example
```julia
resp = elabftw_http("POST", "/api/v2/experiments"; body=Dict("title" => "New"))
new_id = parse(Int, last(split(HTTP.header(resp, "Location"), "/")))
```
"""
function elabftw_http(
    method::AbstractString,
    path::AbstractString;
    body::Union{Dict, Nothing}=nothing,
    query::Union{Dict, Vector, Nothing}=nothing,
)
    _check_enabled()
    url = _elabftw_config.url * _ensure_leading_slash(path)
    isnothing(query) || (url *= "?" * _encode_query(query))
    m = uppercase(String(method))
    if m == "GET"
        return _elabftw_request(url)
    elseif m == "POST"
        return _elabftw_post(url, isnothing(body) ? Dict{String, Any}() : body)
    elseif m == "PATCH"
        return _elabftw_patch(url, isnothing(body) ? Dict{String, Any}() : body)
    elseif m == "DELETE"
        return _elabftw_delete(url)
    else
        throw(ArgumentError("elabftw_http: unsupported method $method"))
    end
end

_ensure_leading_slash(p::AbstractString) = startswith(p, "/") ? String(p) : "/" * String(p)

function _encode_query(q)
    pairs = q isa Dict ? collect(q) : q
    return join([HTTP.escapeuri(String(k)) * "=" * HTTP.escapeuri(string(v))
                 for (k, v) in pairs], "&")
end
