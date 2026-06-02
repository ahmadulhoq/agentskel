# Backlog — agentskel

> Managed by AI Agent. Updated at task-completion. Line count checked at session start.
> P0 = do next session | P1 = this sprint | P2 = someday/nice-to-have
> ID format: BL-NNN (sequential, never reused). Done section capped at 5 entries.
> Jira Ticket: populate when a Jira ticket exists for this item. Leave blank if unplanned in Jira.
> Items without a Jira ticket are local-only intentions — not visible to the team in Jira.

| ID | Priority | Title | Added | Jira Ticket | Notes |
|----|----------|-------|-------|-------------|-------|
| BL-001 | P2 | Multi-project Android skills: deduplicate install across projects | 2026-06-02 | | `.agents/skills/` is per-project, so N Android projects = N copies + N refresh runs. Two options: (a) symlink approach — canonical location like `~/.agentskel-third-party/android/`, setup-skeleton creates symlinks per project; (b) tool-native user-level — `~/.claude/skills/` etc., per-tool guidance only. Trigger: when team has 3+ Android projects and refresh churn becomes annoying. Not urgent. Surfaced in v1.57.x design discussion. |

---

## Done (last 5)

| ID | Title | Completed |
|----|-------|-----------|
