# Repo Config — [APP_NAME] [PLATFORM]
> Managed by: AI Agent + setup-skeleton workflow

---

## Identity

| Field | Value |
|-------|-------|
| Name | [REPO_SHORT_NAME] |
| GitHub | [GITHUB_SLUG] |
| Platform | [PLATFORM] |
| Description | [SHORT_DESCRIPTION] |
| Memory branch | ai-memory |
| Status | pilot |

**Status values:**
- `pilot` — setup complete, cartography not yet done
- `active` — cartography complete, fully operational

Update to `active` once the cartographer workflow finishes.

---

## Operational Config

| Field | Value |
|-------|-------|
| Default Branch | [DEFAULT_BRANCH] |
| Skeleton Version | [SKELETON_VERSION] |
| Skeleton Path | (optional) path to local agentskel clone |
| Blueprint Path | (optional) path to local blueprint (team knowledge) repo |
| Last Blueprint Sync | YYYY-MM-DDTHH:MMZ |
| Last Dependency Check | YYYY-MM-DDTHH:MMZ |
| Last Conventions Check | YYYY-MM-DDTHH:MMZ |
| Last Skeleton Check | YYYY-MM-DDTHH:MMZ |

**Skeleton Path** — optional. If set, `sync-skeleton` and `check-skeleton` workflows read the skeleton from this local path instead of fetching from GitHub. Leave blank if no local clone is available.
**Blueprint Path** — optional. If set, agents read domain knowledge (specs, parity, bus) from this local path. Only needed for multi-project teams with shared domain knowledge.
**Last Blueprint Sync** — updated by `session-start` after reviewing blueprint changes. Used to detect new blueprint commits since last session.
**Last Dependency Check** — updated by `check-dependencies` workflow on completion.
**Last Conventions Check** — updated by `update-conventions` workflow on completion.
**Last Skeleton Check** — updated by `check-skeleton` workflow on completion.
