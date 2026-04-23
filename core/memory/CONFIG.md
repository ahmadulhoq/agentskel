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
| Supported Tools | [SUPPORTED_TOOLS] |
| Last Skeleton Check | YYYY-MM-DDTHH:MMZ |

**Supported Tools** — comma-separated list of tools with native configs installed (e.g. `claude, cursor, copilot`). Valid values: `claude`, `antigravity`, `cursor`, `copilot`, `windsurf`, `codex`. `AGENTS.md` is always installed regardless. Only tools listed here get native config files created/updated during setup and sync.
**Skeleton Path** — optional. If set, `sync-skeleton` and `check-skeleton` workflows read the skeleton from this local path instead of fetching from GitHub. Leave blank if no local clone is available.
**Blueprint Path** — optional. If set, agents read domain knowledge (specs, parity, bus) from this local path. Only needed for multi-project teams with shared domain knowledge.
**Last Blueprint Sync** — updated by `session-start` after reviewing blueprint changes. Used to detect new blueprint commits since last session.
**Last Dependency Check** — updated by `check-dependencies` workflow on completion.
**Last Conventions Check** — updated by `update-conventions` workflow on completion.
**Last Skeleton Check** — updated by `check-skeleton` workflow on completion.

---

## Atlassian Integration (optional)

<!-- Populated by setup-jira and setup-confluence workflows. Only set fields for
     integrations that have been configured. Agent checks these before attempting
     Jira or Confluence operations. -->

| Field | Value |
|-------|-------|
| Jira Site | (optional) e.g. `your-org.atlassian.net` |
| Jira Project Key | (optional) e.g. `PROJ` |
| Confluence Space Key | (optional) e.g. `ENG` |
| Confluence Specs Parent | (optional) page title or ID for specs |
| Confluence ADRs Parent | (optional) page title or ID for ADRs |
| Confluence Runbooks Parent | (optional) page title or ID for runbooks |
| Confluence Postmortems Parent | (optional) page title or ID for post-mortems |

**Jira Site** — set by `setup-jira`. Enables ticket-based workflows (`implement-from-ticket`).
**Confluence Space Key + Parents** — set by `setup-confluence`. Enables publishing workflows (`publish-adr`, `publish-postmortem`, and brainstorm spec publishing).

See `.memory/TEAM.md` for team roster and `.memory/JIRA_WORKFLOW.md` for status transitions and handoff rules (both populated by their respective setup workflows).
