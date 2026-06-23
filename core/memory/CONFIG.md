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
| External Platform Skills | (empty) |
| Last External Skills Check | YYYY-MM-DDTHH:MMZ |
| Direct-Commit Mode | off |
| Autopilot Mode | off |

**Supported Tools** — comma-separated list of tools with native configs installed (e.g. `claude, cursor, copilot`). Valid values: `claude`, `antigravity`, `cursor`, `copilot`, `windsurf`, `codex`. `AGENTS.md` is always installed regardless. Only tools listed here get native config files created/updated during setup and sync.
**Skeleton Path** — optional. If set, `sync-skeleton` and `check-skeleton` workflows read the skeleton from this local path instead of fetching from GitHub. Leave blank if no local clone is available.
**Blueprint Path** — optional. If set, agents read domain knowledge (specs, parity, bus) from this local path. Only needed for multi-project teams with shared domain knowledge.
**Last Blueprint Sync** — updated by `session-start` after reviewing blueprint changes. Used to detect new blueprint commits since last session.
**Last Dependency Check** — updated by `check-dependencies` workflow on completion.
**Last Conventions Check** — updated by `update-conventions` workflow on completion.
**Last Skeleton Check** — updated by `check-skeleton` workflow on completion.
**External Platform Skills** — `(empty)`, `installed`, or `declined`. Records whether the user has installed externally-published platform skill packs (e.g. [android/skills](https://github.com/android/skills)). Set during `setup-skeleton` for relevant platforms. `declined` suppresses re-prompting on sync. See [docs/PLATFORM-SKILLS.md](../docs/PLATFORM-SKILLS.md).
**Last External Skills Check** — updated when external platform skills are installed or refreshed. 30-day cadence; sync-skeleton suggests refresh when overdue.
**Direct-Commit Mode** — `off` (default) or `on`. When `on`, agentskel skips the branch + PR ceremony for the next task: the agent commits and pushes directly to `[Default Branch]`. Everything else stays: plan-first approval gate, task-completion checklist (CHANGELOG/TIME_LOG/RESUME/memory commit), validator, sacred-behaviors check. Use for trivial work where ceremony exceeds the change (typo fixes, version markers, dependency bumps in lockfiles). For one-shot use, prefix a request with `direct:` (e.g. `direct: bump dep X`) instead of flipping the flag. The agent must surface "DIRECT-COMMIT MODE ACTIVE" before any commit while the flag is on. See [`docs/AUTONOMY-MODES.md`](../docs/AUTONOMY-MODES.md) for full procedure and how this mode composes with Autopilot Mode. (Renamed from "Fast Execution Mode" in v1.65.1.)

**Autopilot Mode** — `off` (default) or `on`. When `on`, after a plan has been approved, the agent proceeds within the plan's scope without per-step approval prompts. **Pauses preserved:** significant changes (per the v1.65.0 gate — >30 lines of existing logic / public API change / documented-behavior removal / sacred touch), destructive ops (rm -rf, git push --force, git reset --hard, branch -D), out-of-project paths, dependency changes, scope deviations beyond the approved plan. `session-start` surfaces a one-line banner when the mode is on. Persistent only — no one-shot prefix. Composable with Direct-Commit Mode. See [`docs/AUTONOMY-MODES.md`](../docs/AUTONOMY-MODES.md) for the full boundary definition and behavior under each mode combination.

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
