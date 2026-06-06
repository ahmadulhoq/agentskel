# Session Resume

## Status: IDLE | IN_PROGRESS
IDLE

## Last Completed Task
- v1.62.0: Cross-tool discoverability bundle (Cursor, Windsurf, Copilot, Codex). Audited remaining tools against current 2026 docs. Cursor hooks were silently inactive since v1.22 (wrong path + invented matcher syntax + broken sessionStart) — fixed all three + wrote 4 Cursor-format scripts (Cursor I/O differs from Claude). Generated 50 per-file `.cursor/rules/<name>.mdc` (alwaysApply:false). Windsurf `stop` hook was silent no-op — replaced with `post_cascade_response`; generated 33 `.windsurf/workflows/<name>.md`. Copilot has no hooks concept — deleted `core/copilot-hooks/`; generated 33 `.github/prompts/<name>.prompt.md`. Codex verified working. Validator +3 parity checks (cursor/windsurf/copilot) via factored _flat_stub_parity. 470 ok, 0 fail.

## Previously Completed
- v1.61.0: Gemini CLI / Antigravity parity bundle (3 items): 50 stubs in `.gemini/skills/<name>/SKILL.md` so workflows are skill-discoverable to Gemini; `gemini-extension.json` + `.claude-plugin/plugin.json` bumped to v1.61.0; new `core/gemini-hooks/` with 4 JSON-contract hook scripts + settings.json template; setup-skeleton + sync-skeleton + validator updated. 354 ok, 0 fail.

## Previously Completed
- v1.60.0: Fix Claude Code skill discovery — root cause of "Claude misses all workflows." All 50 stubs migrated from `.claude/skills/<name>.md` (flat, silently ignored by Claude Code's loader) to `.claude/skills/<name>/SKILL.md` (directory, the spec-required format). setup-skeleton + sync-skeleton + validator updated. Downstream migration step added so existing projects auto-convert on next sync via `git mv`. Verified empirically: all 50 skills now appear in the available-skills list.

## Previously Completed
- v1.59.2: Suppress misleading `fatal:` git stderr. `install-agent.sh` memory pull and `sync-skeleton` Step 0 skeleton self-update both redirect `git pull` stderr to `/dev/null`, matching the pattern already used in session-start and pre-memory-push.sh. The `||` fallback still prints the friendly warning. setup-skeleton instruction text also updated. Surfaced by v1.59.1 dogfood test.

## Previously Completed
- v1.59.1: Auto-link external skills on session-start. New Step 1b detects missing symlinks (manifest in `.agents/skills/.gitignore`) and runs `install-agent.sh` once (idempotent). sync-skeleton Step 7 PR body gained accurate post-merge teammate instructions. Replaces the manual "remember to run install-agent.sh" friction surfaced during a downstream sync.
- v1.59.0: Canonical skeleton location at `~/.agentskel/skeleton/`. setup-skeleton and sync-skeleton auto-resolve + auto-update the skeleton source — no "where is your agentskel clone?" prompt for new users.
- v1.58.0: Shared external skills store at `~/.agentskel/skills/`. Projects get gitignored symlinks. New `core/external-skills.yml` manifest (adding packs requires only a YAML entry). New `update-external-skills` workflow. sync-skeleton Step 4d migrates old-style installs automatically. install-agent.sh recreates symlinks on clone via `.gitignore` manifest.
- v1.57.3: setup-skeleton Step 9c install verification gate — tightened wording so agents don't flip `External Platform Skills` flag to `installed` without a confirming filesystem scan.
- v1.57.2: setup-skeleton step ordering fix (Step 9c moved before git commit) + `gh repo edit --default-branch` added after ai-memory push (pin GitHub default branch on brand-new repos).

## Previously Completed
- v1.57.0: External platform skills (Android, reference-don't-vendor). docs/PLATFORM-SKILLS.md, setup-skeleton Step 9c, sync-skeleton Step 4d (30-day refresh cadence + 3-option prompt + declined flag), CONFIG.md fields (External Platform Skills, Last External Skills Check), developer/SKILL.md pointer, validator distinguishes first-party vs third-party for stub + catalog parity. Also fixed pre-existing README v1.55.4 + Skeleton Version v1.50.0 drift. PR #37 merged.

## Previously Completed
- v1.55.0: Post-sync workflow/skill triage via affected: field. CHANGELOG entries for skeleton now include affected: names. sync-skeleton Step 4d + Final Step triage. task-completion + checklist updated.

## Previously Completed
- v1.54.2: Workflow plan gate strengthening. "Concerns ≠ plan" definition added to develop-feature, implement-task, fix-tech-debt, refactor-code. Missing approval gate added to debug-issue before Phase 4. 10 workflow files changed.

## Previously Completed
- v1.54.1: agentskills.io Gaps 1+2+4 — license: MIT (all SKILL.md), compatibility (skill-authoring), task-completion/references/, skill-authoring guide updated. Gap 5 N/A.
- v1.54.0: agentskills.io Gap 3 — multi-line YAML description support. validate.py _extract_description(), 1024-char limit, pre-commit hook, skill-authoring, sync-skeleton Step 4c.

## Previously Completed
- v1.53.1: Fix session-start not triggered post-setup (folded into Final Step). Add post-merge cleanup to git-flow (branch -d, remote prune, RESUME update).
- v1.35-v1.36: Pre-commit hook worktree detection fix, sync-skeleton cd .memory directory bleed fix.
- v1.34: Native-first rule delivery + deterministic enforcement hooks. .claude/rules/ auto-load, AGENTS.md inline, condensed configs, pre-commit hook, 10 skill-wiring gaps fixed. PR #31 merged.
- v1.31: refactor-code workflow (4-phase safe restructure). CSO description fixes (systematic-debugger, domain-expert, task-planner wired into develop-feature). Session-start mandate added directly to all tool config files and templates (CLAUDE.md, GEMINI.md, Cursor, Copilot, Windsurf) — was only in AGENTS.md which tools read lazily. sync-skeleton propagates fix to downstream projects.

## Next Task
- (none)

## Session Notes
- (none)

## Context Notes (Persistent)
- agentskel is the skeleton repo itself — Skeleton Path = `.` in CONFIG.md
- `.agents/` contains copies (not symlinks) of core/ and roles/dev/ files, synced via sync-skeleton
- MASTER_PLAN.md tracked in git since v1.6; MAINTAIN_MASTER_PLAN.md is gitignored (private maintenance checklist)
- roles/devops/ is a placeholder (not implemented)
- CONFIG.md Skeleton Version is tracked in `.memory/CONFIG.md` (currently 1.59.2 as of 2026-06-03)
- RULES.md now holds project context + project rules only (behavioral rules in .agents/rules/)
- CONFIG.md has Description field for project identity (moved from RULES.md in v1.18)
- v1.19: All operational timestamps use ISO 8601 UTC format (YYYY-MM-DDTHH:MMZ)
- v1.20: Cartographer indexes ADR sections into MAP.md (step 6b)
- v1.21: AGENTS.md is the universal entry point (AGENTS.md open standard, Linux Foundation). CLAUDE.md/GEMINI.md are thin wrappers. One canonical source (.agents/ + .memory/), many entry points.
- v1.22: Tool configs are opt-in via Supported Tools field. Native thin wrappers for Cursor/Copilot/Windsurf. Only AGENTS.md is unconditional.
- v1.23: Session reload triggers — session-start re-executes after sync, setup, or 24h staleness.
- v1.24: Skill authoring guide (meta-skill) + CSO descriptions for 11 workflows.
- v1.25: Rationalization resistance tables + subagent-dispatch skill with prompt templates.
- v1.26: Plugin-based install (Claude Code, Cursor, Gemini CLI) + session-start hook + README simplification.
- v1.27: Renamed senior-developer→developer. Extracted skeleton checklist from task-completion.
- v1.28: Platform trimming gate in sync-skeleton (Step 4b). Caught by PR review on Muslim-Pro-Android.

- v1.29: All named functions in SYMBOLS + module-based split (5+ modules) + codebase-navigator skill.
- v1.30: brainstorm-feature + debug-issue workflows. TDD, systematic-debugger, using-git-worktrees skills.
- v1.31-v1.33: refactor-code workflow, CSO sharpening, session-start mandate in all tool configs, VERSION bump in skeleton checklist.
- v1.34: Native-first rule delivery (.claude/rules/ auto-load, AGENTS.md inline, condensed configs). Deterministic pre-commit hook. 10 skill-wiring gaps fixed.

## Cartography State
- Last indexed commit: 3814944b8a16c6d2a5c426674423ada902837055
- Last indexed date: 2026-06-03
- Coverage target: 262 source files (.md, .sh, .py, .yml, .json, .mdc, .template; excluding .git/ and .memory/)
- Symbols format: single (SYMBOLS.md holds all symbols directly — agentskel itself has few code symbols beyond scripts/validate.py)
- [x] core/memory (18 files)
- [x] core/rules (2 files)
- [x] core/skills (9 directories — atlassian-integration, codebase-navigator, discussion-continuity, git-flow, knowledge-routing, session-start, skill-authoring, subagent-dispatch, task-completion)
- [x] core/claude-rules (3 files)
- [x] core/claude-hooks (5 files — pre-commit-check, pre-memory-push, pre-edit-check, stop-verify, settings.json)
- [x] core/cursor-hooks (2 files), core/windsurf-hooks (1), core/copilot-hooks (1), core/codex-hooks (1)
- [x] core/workspace-templates (7 files — dispatcher templates)
- [x] core/ root (8 files — 3 entry-point templates, 3 native-config templates, condensed-rules.md, external-skills.yml)
- [x] roles/dev/workflows (33 files)
- [x] roles/dev/skills (8 directories — code-reviewer, developer, domain-expert, systematic-debugger, task-planner, test-driven-development, test-engineer, using-git-worktrees)
- [x] roles/dev/standards (7 files)
- [x] roles/dev/prompts (8 files)
- [x] roles/devops (1 placeholder file)
- [x] .agents/ (60 installed copies — 17 skills, 33 workflows, 3 rules, 7 standards)
- [x] .claude/skills/ (50 auto-generated stubs)
- [x] .claude/rules/ (3 files), .claude/hooks/ (4 files), .claude/settings.json
- [x] .claude-plugin/ (2 manifest files)
- [x] docs/ (4 files — ATLASSIAN-SETUP, INSTALL-MODES, PLATFORM-SKILLS, TEAM-COORDINATION)
- [x] scripts/ (2 files — install-agent.sh, validate.py)
- [x] Root files (VERSION, CHANGELOG.md, README.md, MASTER_PLAN.md, MAINTAIN_MASTER_PLAN.md, AGENTS.md, CLAUDE.md, GEMINI.md, CONTRIBUTING.md, INSTALL.md, LICENSE, .gitignore, .claudeignore) + native tool configs (.cursor/rules/agentskel.mdc, .github/copilot-instructions.md, .windsurf/rules/agentskel.md)
- Coverage gate passed — all top-level directories under git tracking accounted for. 0 unprocessed.
- Note: this was a refresh (not a full re-cartography). SYMBOLS.md scripts section was updated at v1.57.0; other sections unchanged from previous cartography. A full re-index would require reading every workflow and skill source file — deferred to a future cartographer run when justified by significant structural change.

## Timestamp (UTC)
- 2026-06-07T19:00Z
