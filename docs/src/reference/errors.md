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

## When each error fires

| Situation | Exception |
|---|---|
| `configure_elabftw` never called, or `disable_elabftw()` is active | `NotConfiguredError` |
| API key missing / invalid | `AuthError` |
| API key valid but action not permitted | `PermissionError` |
| Entity doesn't exist or isn't visible | `NotFoundError` |
| Rate limit exceeded (after retries exhausted) | `RateLimitError` (carries `retry_after`) |
| Server 5xx (after retries exhausted) | `ServerError` |
| Other 4xx (e.g. 422 validation error, 400 bad body) | `ClientError` |
| Network / DNS / TLS / socket failure | `NetworkError` |
| Malformed response body, unparseable `Location` | `ParseError` |
| Bad argument (bad enum, missing required kwarg, wrong Symbol) | `ArgumentError` *(stdlib)* |

Notable non-obvious cases:

- **`sign_experiment` / `sign_item`** with missing or misconfigured signing keys — the server returns HTTP **500**, not 422. Surfaces as `ServerError` after retry exhaustion.
- **`notif_step` / `notif_item_step`** on a step with no `deadline` — server returns HTTP **500**. Use [`update_step`](@ref) to set a deadline first.
- **`delete_storage_unit`** on a unit with children or containers — `ClientError` (status 422). Empty children/containers first.
- **`create_container`** internally fetches the listing after POST to find the new row ID (the server's `Location` header is unusable for this endpoint). If the listing has no matching row, raises `ParseError`.

See per-function `# Throws` sections for argument-validation specifics.

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
