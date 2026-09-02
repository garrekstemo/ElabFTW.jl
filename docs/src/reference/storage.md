# Storage

Track physical storage locations for inventory items. Two concepts:

- **Storage units** — a hierarchical tree of locations (freezer → shelf →
  drawer → box). Pure location metadata, no quantities.
- **Containers** — per-entity assignments of the form "item 42 is stored in
  unit 7, 50 mL". Each container row attaches to one experiment or item.

## Storage units

```@docs
list_storage_units
get_storage_unit
create_storage_unit
update_storage_unit
rename_storage_unit
delete_storage_unit
```

## Containers

```@docs
list_containers
get_container
create_container
update_container
delete_container
```

## Notes on eLabFTW's storage API

A few quirks worth knowing:

- `GET /storage_units` (what `list_storage_units()` calls with no arguments)
  returns **container assignments**, not the list of units. Pass
  `hierarchy=true` to get the unit tree.
- `PATCH` on a storage unit accepts `name`, `parent_id`, or both (at least
  one is required). Pass `parent_id` to reparent a unit (and everything under
  it) in place. Use the `elabftw_http` escape hatch to move a unit to the
  root (`parent_id: null` cannot be expressed as a Julia `Int`).
- The `qty_unit` field is stored as a free-form string truncated to 10
  characters. The spec lists `"bar"`, `"•"`, `"m"`, `"μL"`, `"mL"`, `"L"`,
  `"μg"`, `"mg"`, `"g"`, `"kg"` — the UI expects these, but the server will
  accept anything.
- On container creation, the server's `Location` header points at an
  unusable URL. `create_container` works around this by listing containers
  after the POST and returning the newest row matching the `storage_id`.
