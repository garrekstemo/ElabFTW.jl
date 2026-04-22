# Typed exception hierarchy for eLabFTW operations.
#
# Callers can pattern-match on concrete types:
#     try
#         get_item(id)
#     catch e
#         e isa NotFoundError ? ... : rethrow()
#     end
#
# All HTTP-backed errors share the `HTTPError` abstract supertype; everything
# this package throws is under `ElabFTWError`.

"""
    ElabFTWError

Abstract supertype for every exception thrown by ElabFTW.jl.
"""
abstract type ElabFTWError <: Exception end

"""
    HTTPError <: ElabFTWError

Abstract supertype for errors tied to an HTTP response.
"""
abstract type HTTPError <: ElabFTWError end

"""
    NotConfiguredError <: ElabFTWError

Raised by API calls when `configure_elabftw` has not been called (or the
integration has been disabled via [`disable_elabftw`](@ref)).
"""
struct NotConfiguredError <: ElabFTWError end

Base.showerror(io::IO, ::NotConfiguredError) =
    print(io, "eLabFTW not enabled. Call configure_elabftw() first.")

"""
    AuthError(url) <: HTTPError

HTTP 401 — the API key is missing or invalid.
"""
struct AuthError <: HTTPError
    url::String
end

Base.showerror(io::IO, e::AuthError) =
    print(io, "eLabFTW authentication failed (401). Check your API key. URL: ", e.url)

"""
    PermissionError(url) <: HTTPError

HTTP 403 — the key is valid but lacks permission for this action.
"""
struct PermissionError <: HTTPError
    url::String
end

Base.showerror(io::IO, e::PermissionError) =
    print(io, "eLabFTW permission denied (403). URL: ", e.url)

"""
    NotFoundError(url) <: HTTPError

HTTP 404 — resource doesn't exist or isn't visible to the caller.
"""
struct NotFoundError <: HTTPError
    url::String
end

Base.showerror(io::IO, e::NotFoundError) =
    print(io, "eLabFTW resource not found (404): ", e.url)

"""
    RateLimitError(url, retry_after) <: HTTPError

HTTP 429 — too many requests. `retry_after` is the server's advisory wait
(in seconds, parsed from the `Retry-After` header) or `nothing` if absent.
Raised only after the retry budget is exhausted.
"""
struct RateLimitError <: HTTPError
    url::String
    retry_after::Union{Int, Nothing}
end

function Base.showerror(io::IO, e::RateLimitError)
    print(io, "eLabFTW rate limit exceeded (429) for ", e.url)
    isnothing(e.retry_after) || print(io, "; Retry-After=", e.retry_after, "s")
end

"""
    ServerError(status, url, body) <: HTTPError

HTTP 5xx — server-side failure. Raised after retries are exhausted.
"""
struct ServerError <: HTTPError
    status::Int
    url::String
    body::String
end

Base.showerror(io::IO, e::ServerError) =
    print(io, "eLabFTW server error (", e.status, ") for ", e.url,
          isempty(e.body) ? "" : ": " * first(e.body, 200))

"""
    ClientError(status, url, body) <: HTTPError

HTTP 4xx not otherwise specialized (e.g. 400 Bad Request, 422 Unprocessable).
"""
struct ClientError <: HTTPError
    status::Int
    url::String
    body::String
end

Base.showerror(io::IO, e::ClientError) =
    print(io, "eLabFTW client error (", e.status, ") for ", e.url,
          isempty(e.body) ? "" : ": " * first(e.body, 200))

"""
    NetworkError(message, cause) <: ElabFTWError

The request never completed due to a transport-layer failure (DNS, TLS,
socket). `cause` is the underlying exception, if any.
"""
struct NetworkError <: ElabFTWError
    message::String
    cause::Union{Exception, Nothing}
end

Base.showerror(io::IO, e::NetworkError) =
    print(io, "eLabFTW network error: ", e.message)

"""
    ParseError(message) <: ElabFTWError

The server returned a response that couldn't be interpreted — missing
`Location` header, unparseable JSON, etc.
"""
struct ParseError <: ElabFTWError
    message::String
end

Base.showerror(io::IO, e::ParseError) =
    print(io, "eLabFTW response parse error: ", e.message)

"""
    _http_error(status::Int, url::String, body::String) -> HTTPError

Map an HTTP status to the most specific error type. Rate-limit extraction
of `Retry-After` is done at the call site (where the response is still
available).
"""
function _http_error(status::Integer, url::String, body::String="")
    s = Int(status)
    s == 401 && return AuthError(url)
    s == 403 && return PermissionError(url)
    s == 404 && return NotFoundError(url)
    s == 429 && return RateLimitError(url, nothing)
    s >= 500 && return ServerError(s, url, body)
    return ClientError(s, url, body)
end
