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
| Skeleton Version | 1.28 |
| Skeleton Path | . |
| Blueprint Path | |
| Last Blueprint Sync | |
| Last Dependency Check | YYYY-MM-DDTHH:MMZ |
| Last Conventions Check | YYYY-MM-DDTHH:MMZ |
| Supported Tools | claude, antigravity, cursor, copilot, windsurf |
| Last Skeleton Check | YYYY-MM-DDTHH:MMZ |

**Supported Tools** — comma-separated list of tools with native configs installed. Valid values: `claude`, `antigravity`, `cursor`, `copilot`, `windsurf`, `codex`. `AGENTS.md` is always installed regardless. Only tools listed here get native config files created/updated during setup and sync.
**Skeleton Path** — points to `.` (repo root) because this repo IS the skeleton. `sync-skeleton` reads templates from `core/` and `roles/` within the same repo.
**Blueprint Path** — optional. If set, agents read domain knowledge (specs, parity, bus) from this local path. Only needed for multi-project teams with shared domain knowledge.
**Last Dependency Check** — updated by `check-dependencies` workflow on completion.
**Last Conventions Check** — updated by `update-conventions` workflow on completion.
**Last Skeleton Check** — updated by `check-skeleton` workflow on completion.
