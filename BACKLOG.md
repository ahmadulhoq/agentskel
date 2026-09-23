# Backlog — agentskel

> Managed by AI Agent. Updated at task-completion. Line count checked at session start.
> P0 = do next session | P1 = this sprint | P2 = someday/nice-to-have
> ID format: BL-NNN (sequential, never reused). Done section capped at 5 entries.
> Jira Ticket: populate when a Jira ticket exists for this item. Leave blank if unplanned in Jira.
> Items without a Jira ticket are local-only intentions — not visible to the team in Jira.

| ID | Priority | Title | Added | Jira Ticket | Notes |
|----|----------|-------|-------|-------------|-------|
| BL-001 | P1 | Decide the fate of feat/v1.68.0-batch (items 3-6 unrecoverable) | 2026-09-23 | | Branch holds 2 complete doc commits: item 1 = Autopilot Mode ↔ Claude Code Auto Mode composition (docs/AUTONOMY-MODES.md +39); item 2 = CONTRIBUTING.md self-sync refresh (+88/-9), which fixes the stale "4-location" text that now needs 6 skill + 8 workflow locations — the exact friction observed on PR #55. Items 3-6 were named by number only in a prior session's context and never written down; searched BACKLOG, Session Notes, TECH_DEBT, NEEDS_REVIEW, branch commits, reflog and both PR lists on 2026-09-23, nothing. **Recommendation: ship items 1-2 as their own PR rather than holding two finished doc fixes for four forgotten ones.** Rebased onto v1.67.1; remote still on the pre-rebase history, so pushing needs a force-with-lease (blocked by pre-bash-safety, needs explicit human go-ahead). |
| BL-002 | P1 | CONTRIBUTING.md "Validation" section is stale and one item actively misleads | 2026-09-23 | | Found 2026-09-23 while rebasing feat/v1.68.0-batch. Says "six deterministic checks" (now 11) and the list is years behind: **"single-line descriptions — descriptions don't fold across YAML lines" has been wrong since v1.54.0**, which added folded-scalar support; the real check is length <=1024 chars, so the doc tells contributors to avoid something explicitly supported. Also: version consistency covers 5 files not 3 (v1.62.1 added the two plugin manifests); stub parity cites flat `.claude/skills/*.md`, wrong since v1.60.0's directory layout, and omits the gemini/cursor/windsurf/copilot parity checks (v1.61.0, v1.62.0); missing inline-rules propagation (v1.64.0-gap) and no-unreleased-skeleton-changes (v1.67.1). Same defect class item 2 exists to fix — it refreshed the self-sync tables directly above and left this section untouched. Fix alongside items 1-2. |

---

## Done (last 5)

| ID | Title | Completed |
|----|-------|-----------|
