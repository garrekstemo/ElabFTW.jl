# TODO

Checklist derived from a gap analysis against the official eLabFTW v2
OpenAPI spec (`elabftw/apidoc/v2/openapi.yaml`) and the reference Python
client (`elabftw/elabapi-python`).

## Existing backlog

- [ ] Review codecov report and fill test coverage gaps
- [ ] Register package in Julia General registry
- [ ] Proxy project docs through garrek.org Worker (optional)

## Smaller feature gaps (worth picking up opportunistically)

_None — all API endpoints covered._

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

_None open._

## Docs & infra

- [ ] Docstrings: add "Throws" sections to exported functions (audit + backfill)
