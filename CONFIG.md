# Repo Config — agentskel Framework
> Managed by: AI Agent + setup-skeleton workflow

---

## Identity

| Field | Value |
|-------|-------|
| Name | agentskel |
| GitHub | ahmadulhoq/agentskel |
| Platform | Framework (shell/markdown) |
| Memory branch | ai-memory |
| Status | active |

**Status values:**
- `pilot` — setup complete, cartography not yet done
- `active` — cartography complete, fully operational

Update to `active` once the cartographer workflow finishes.

---

## Operational Config

| Field | Value |
|-------|-------|
| Default Branch | main |
| Skeleton Version | 1.5 |
| Skeleton Path | . |
| Blueprint Path | |
| Last Blueprint Sync | |
| Last Dependency Check | YYYY-MM-DD |
| Last Conventions Check | YYYY-MM-DD |
| Last Skeleton Check | YYYY-MM-DD |

**Skeleton Path** — points to `.` (repo root) because this repo IS the skeleton. `sync-skeleton` reads templates from `core/` and `roles/` within the same repo.
**Blueprint Path** — optional. If set, agents read domain knowledge (specs, parity, bus) from this local path. Only needed for multi-project teams with shared domain knowledge.
**Last Dependency Check** — updated by `check-dependencies` workflow on completion.
**Last Conventions Check** — updated by `update-conventions` workflow on completion.
**Last Skeleton Check** — updated by `check-skeleton` workflow on completion.
