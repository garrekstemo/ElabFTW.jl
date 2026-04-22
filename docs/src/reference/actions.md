# Actions

State-changing actions on experiments and items — locking, pinning,
RFC 3161 timestamping, and cryptographic signatures. Each wrapper sends
`PATCH /{entity_type}/{id}` with an `{"action": ...}` payload and returns
the updated entity record.

## Lock and pin

Both `lock` and `pin` are **toggles** at the API level — calling them on
an already-locked (or pinned) entity flips the state back. This matches
the eLabFTW spec and the UI behavior.

```@docs
lock_experiment
lock_item
pin_experiment
pin_item
```

## Timestamp (RFC 3161)

```@docs
timestamp_experiment
timestamp_item
```

Requires the eLabFTW instance to have a trusted timestamping service
configured. If it's not configured, the server returns HTTP 500 (surfaced
as [`ServerError`](@ref) after retry exhaustion).

## Sign

```@docs
sign_experiment
sign_item
SIGN_MEANING
```

Signing needs server-side signing keys. If they aren't configured, or the
passphrase is wrong, the server responds with HTTP 500 (not 400) — this
is a known eLabFTW quirk. Watch for `ServerError` on failure.

Accepts either an `Int` (10/20/30/40/50) or a `Symbol` (`:approval`,
`:authorship`, `:responsibility`, `:review`, `:safety`) for `meaning`.
