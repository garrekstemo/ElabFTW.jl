# TODO

Checklist derived from a gap analysis against the official eLabFTW v2
OpenAPI spec (`elabftw/apidoc/v2/openapi.yaml`) and the reference Python
client (`elabftw/elabapi-python`).

## Existing backlog

- [ ] Review codecov report and fill test coverage gaps
- [ ] Register package in Julia General registry
- [ ] Proxy project docs through garrek.org Worker (optional)

## Smaller feature gaps (worth picking up opportunistically)

- [ ] **Steps DELETE and `notif` action** — spec supports both; we only do
      list/add/finish.
- [ ] **Full CRUD on categories** — currently `list_experiments_categories` and
      `list_items_categories` are read-only. Spec has POST/PATCH/DELETE on
      `/teams/{id}/{experiments,resources}_categories/{subid}`.
- [ ] **Status endpoints** — `/teams/{id}/experiments_status` and `items_status`
      are not implemented at all. Full CRUD per spec.
- [ ] **Extra fields keys** — `GET /extra_fields_keys?q=` returns autocomplete
      suggestions for metadata keys. Useful for form builders.

## Admin surface (defer until needed)

- [ ] **Users** — `/users`, `/users/{id}` (PATCH actions: `archive`, `validate`,
      `add`/`unreference` to team, `disable2fa`, `updatepassword`, `patchuser2team`)
- [ ] **Teams** — `/teams`, `/teams/{id}` (sysadmin-only create; PATCH with
      `action=sendonboardingemails`)
- [ ] **Teamgroups** — `/teams/{id}/teamgroups` with membership PATCH
- [ ] **API keys** — `/apikeys` list/create/delete (create returns cleartext key
      in `Location` header)
- [ ] **Notifications** — `/users/{id}/notifications` with `is_ack` toggle
- [ ] **Todolist** — `/todolist` personal task CRUD
- [ ] **Unfinished steps** — `GET /unfinished_steps?scope=user|team` dashboard
- [ ] **Config** — `GET/PATCH/DELETE /config` (sysadmin instance config)
- [ ] **IdPs + IdPs sources** — `/idps`, `/idps_sources` SAML management
- [ ] **Reports** — `GET /reports?format=csv|json&scope=...`
- [ ] **DSpace** — `/dspace` submission integration
- [ ] **User uploads** — `GET /users/{id}/uploads` per-user attachment listing

## Bugs & known issues

- [ ] Consider whether `tag_experiments`/`tag_items` batch helpers should accept
      arrays rather than one tag at a time (requires checking the batch
      semantics against the live server).
- [ ] Auth header format works but `test_connection()` doesn't verify the
      header name/value style the API actually wants — add a regression test.

## Docs & infra

- [ ] How-to guide: batch operations (`batch.md` reference exists but no recipe)
- [ ] How-to guide: compounds / chemical inventory
- [ ] How-to guide: events / scheduler bookings
- [ ] How-to guide: `extra_fields` / metadata forms
- [ ] Document rate limits and error handling patterns in `index.md`
- [ ] Docstrings: add "error conditions" / "throws" to exported functions
- [ ] Tests: malformed JSON, network timeout, concurrent request safety
- [ ] Tests: explicit 4xx/5xx paths (currently only 401/403/404 covered implicitly)
