# Errors and HTTP

All exceptions thrown by ElabFTW.jl inherit from `ElabFTWError`. HTTP-backed
errors further share the `HTTPError` supertype, so callers can pattern-match
at whatever granularity they want:

```julia
try
    get_experiment(id)
catch e
    if e isa NotFoundError
        # create a fresh one
    elseif e isa HTTPError
        # any other HTTP failure
    else
        rethrow()
    end
end
```

## Exception hierarchy

```@docs
ElabFTWError
HTTPError
NotConfiguredError
AuthError
PermissionError
NotFoundError
RateLimitError
ServerError
ClientError
NetworkError
ParseError
```

## Retry behavior

Requests that return HTTP 5xx or 429 are retried automatically with
exponential backoff. Tune via `configure_elabftw`:

- `max_retries` (default `3`) — maximum retry attempts after the first try.
- `retry_base_delay` (default `0.5` seconds) — base delay; each retry waits
  `base * 2^(attempt-1)` seconds.

For 429 responses with a `Retry-After` header, the server's hint is used
instead of the exponential schedule. When all retries are exhausted, the
final error is thrown as a typed `ServerError` or `RateLimitError` — the
latter carries the parsed `retry_after` value.

4xx responses other than 429 are **not** retried; they surface as
`AuthError` (401), `PermissionError` (403), `NotFoundError` (404), or
`ClientError` (any other 4xx).

## Low-level HTTP escape hatch

When you need something the typed helpers don't expose — response headers,
unusual verbs, pagination metadata — drop down one layer with
`elabftw_http`. It applies the same authentication, retry, and typed-error
handling as the higher-level functions, but returns the raw
`HTTP.Response`.

```@docs
elabftw_http
```
