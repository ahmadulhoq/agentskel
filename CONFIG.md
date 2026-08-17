# Repo Config — agentskel Framework
> Managed by: AI Agent + setup-skeleton workflow

---

## Identity

| Field | Value |
|-------|-------|
| Name | agentskel |
| GitHub | ahmadulhoq/agentskel |
| Platform | Framework (shell/markdown) |
| Description | AI agent framework — workflows, skills, rules, standards, and memory management for consistent agent behavior across projects |
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
| Skeleton Version | 1.67.0 |
| Skeleton Path | . |
| Blueprint Path | |
| Last Blueprint Sync | |
| Last Dependency Check | 2026-05-09T00:00Z |
| Last Conventions Check | YYYY-MM-DDTHH:MMZ |
| Supported Tools | claude, antigravity, cursor, copilot, windsurf |
| Last Skeleton Check | 2026-04-11T19:01Z |
| External Platform Skills | (empty) |
| Last External Skills Check | |
| Direct-Commit Mode | off |
| Autopilot Mode | on |

**Supported Tools** — comma-separated list of tools with native configs installed. Valid values: `claude`, `antigravity`, `cursor`, `copilot`, `windsurf`, `codex`. `AGENTS.md` is always installed regardless. Only tools listed here get native config files created/updated during setup and sync.
**Skeleton Path** — points to `.` (repo root) because this repo IS the skeleton. `sync-skeleton` reads templates from `core/` and `roles/` within the same repo.
**Blueprint Path** — optional. If set, agents read domain knowledge (specs, parity, bus) from this local path. Only needed for multi-project teams with shared domain knowledge.
**Last Dependency Check** — updated by `check-dependencies` workflow on completion.
**Last Conventions Check** — updated by `update-conventions` workflow on completion.
**Last Skeleton Check** — updated by `check-skeleton` workflow on completion.
**External Platform Skills** — `(empty)`, `installed`, or `declined`. agentskel itself isn't a platform project (no `Platform` set in Identity), so this stays `(empty)`. Field added in v1.57.0; backfilled here in v1.63.1 self-sync.
**Last External Skills Check** — populated when external-skills install/refresh runs. N/A for the skeleton itself.

---

## Atlassian Integration (optional)

| Field | Value |
|-------|-------|
| Jira Site | |
| Jira Project Key | |
| Confluence Space Key | |
| Confluence Specs Parent | |
| Confluence ADRs Parent | |
| Confluence Runbooks Parent | |
| Confluence Postmortems Parent | |

agentskel itself doesn't use Atlassian integration (this repo is the framework, not a team project). Fields added in v1.49.0; backfilled here in v1.63.1 self-sync. Downstream teams populate via `setup-jira` / `setup-confluence` workflows.
