# Agent Changelog: agentskel

<!-- Log every change with description and reasoning.
     Format: ## [DATE] — [Short Description]
     Include: what changed, why, files affected, any risks. -->

## 2026-04-18 — v1.48.1: README simplification + INSTALL-MODES doc

Simplified README for first-time users: removed framework jargon from
early sections, kept Getting started to 3 plain-language questions.
New docs/INSTALL-MODES.md with ASCII diagrams showing shape (not
filesystem) of each setup. Detailed content moved out of README.

## 2026-04-18 — v1.48.0: workspace dispatcher install mode

New install mode for workspaces with multiple independent projects. Workspace
root becomes a thin routing dispatcher; each subdir retains its own independent
install. 8 new templates in core/workspace-templates/, 4 new workflows
(setup-workspace, add/remove/sync-workspace-*), setup-skeleton Step 0 + 9b,
session-start hook workspace detection, README Install modes section,
MASTER_PLAN principle #13. Monorepo explicitly not supported.

## 2026-04-17 — v1.47.0: semver three-part versioning

Moved VERSION to X.Y.Z format. Updated skeleton-contribution-checklist and
core-behavior to classify MAJOR/MINOR/PATCH. Pre-commit hook regex handles both
X.Y and X.Y.Z during transition. Going forward every change is classified.
Files: core/skills/task-completion/skeleton-contribution-checklist.md,
core/rules/core-behavior.md, core/claude-hooks/pre-commit-check.sh,
.agents/ copies, VERSION, README, MASTER_PLAN.

## 2026-04-17 — v1.46: pre-commit hook fixes (false positives + wall-clock)

Hook now explicitly checks command is `git commit` (not `git log`, `git status`).
Removed `--since="8 hours ago"` wall-clock dependency — replaced with last-commit
or dirty-files check (works across day boundaries). Replaced GNU-only grep -oP
with portable grep -oE for macOS compatibility.
Files: core/claude-hooks/pre-commit-check.sh, core/claude-hooks/pre-memory-push.sh,
.claude/hooks/ copies. Reported by downstream Muslim-Pro-Android agent.

## 2026-04-17 — v1.45: cross-tool enforcement hooks + GEMINI.md condensed rules

Enforcement hooks (pre-commit, pre-push, stop) now have templates for all 5 tools.
GEMINI.md upgraded from thin wrapper to condensed rules inline. setup-skeleton
Step 5b3 installs hooks for all supported tools.
Files: 4 new core/*-hooks/ directories, GEMINI.md template + self-install,
setup-skeleton updated.

## 2026-04-17 — v1.42: subagent dispatch simplification

Rewrote subagent-dispatch skill: parent passes plan steps instead of templates.
Deleted prompts/ directory. Changed "consider" to "use" in workflows. Added
mandatory review dispatch to develop-feature Phase 4.
Files: core/skills/subagent-dispatch/SKILL.md, prompts/ deleted, 3 workflows updated.

## 2026-04-17 — v1.41: session-start context optimization

VERSIONS.md removed from session-start (loaded by workflows instead). RESUME.md
partial read up to --- marker. NEEDS_REVIEW.md line-count check instead of full read.
RESUME.md template restructured with deferrable sections below marker.
Files: core/skills/session-start/SKILL.md, core/memory/RESUME.md, .agents/ copies.

## 2026-04-17 — v1.40: stop hook precision + NEEDS_REVIEW triage escalation

Stop hook no longer triggers for pure analysis/discussion sessions. Cartographer
Step 9 now creates a TECH_DEBT entry for untriaged NEEDS_REVIEW items so triage
surfaces when asking "what's pending?" Removed erroneous analysis CHANGELOG entry.
Files: core/claude-hooks/settings.json, roles/dev/workflows/cartographer.md,
.claude/settings.json, .agents/workflows/cartographer.md.

## 2026-04-16 — Session summary: v1.34→v1.39 (5 releases in one session)

Complete session scope: native-first rule delivery architecture, enforcement hooks,
operational audit, and iterative hook hardening.

- **v1.34**: Architecture change — rules moved to native auto-load locations
  (.claude/rules/, AGENTS.md inline, condensed in Cursor/Windsurf/Copilot).
  Pre-commit hook blocks commits without CHANGELOG/TIME_LOG. Stop hook verifies
  task-completion. 10 skill-wiring gaps fixed across 7 workflows. 45 files changed.
- **v1.37**: INSTALL.md for issue #30 (manual install for Cursor/Copilot/Windsurf/Codex).
- **v1.38**: Pre-memory-push hook (auto-pull before ai-memory push). Operational
  audit found 30+ gaps: pre-commit 1h window, task type mismatch, error suppression,
  race conditions, missing recovery paths.
- **v1.39**: Hook hardening — VERSION/README/MASTER_PLAN consistency check, 8h session
  window, pull error reporting, dirty worktree detection.
- **Context load analysis**: measured startup cost (~1,400 tokens small project,
  ~1,800 large). Identified 17-41% savings via deferred loading of RESUME, VERSIONS,
  LESSONS, NEEDS_REVIEW, and partial MAP reads. Queued for implementation.

Compliance baseline measured on Muslim-Pro-Android: 0/6 bug fixes had CHANGELOG
or TIME_LOG entries. After hooks: deterministically enforced (100%).

## 2026-04-16 — v1.39: hook hardening

Pre-commit hook now checks VERSION/README/MASTER_PLAN version consistency for
skeleton repos. Catches the version drift that was missed every release since v1.34.
Session window widened from 1 hour to 8 hours. Pre-memory-push hook no longer
suppresses pull errors with || true.

## 2026-04-16 — v1.38: enforced auto-pull before ai-memory push + operational audit

New PreToolUse hook (pre-memory-push.sh) auto-runs git pull --rebase before any
push to ai-memory. Comprehensive operational audit identified 30+ gaps across
git operations, race conditions, hook logic, and error handling. Critical findings:
pre-commit hook 1-hour window causes false positives on long sessions, hook doesn't
distinguish development vs analysis tasks, pre-memory-push suppresses errors with
|| true. These are queued for immediate fix.

## 2026-04-16 — v1.38: enforced auto-pull before ai-memory push

New PreToolUse hook (pre-memory-push.sh) auto-runs git pull --rebase before any
push to ai-memory. Prevents the non-fast-forward conflicts that happened when
this session tried to push after another agent had pushed v1.35/v1.36. Hook fires
at the transport layer — agents cannot skip it.

## 2026-04-16 — v1.37: INSTALL.md for issue #30

Created INSTALL.md with manual installation instructions for Cursor, Copilot,
Windsurf, and Codex CLI. Resolves issue #30 (INSTALL.md referenced in README
but missing). VERSION bumped to 1.37, CHANGELOG entry added.

## 2026-04-15 — v1.34: native-first rule delivery + enforcement hooks

Architecture change: rules moved from `.agents/rules/` (not auto-loaded) to each
tool's native auto-load location. Measured baseline: 0/6 bug fixes on Muslim-Pro-Android
had CHANGELOG or TIME_LOG entries. Root cause: 3-hop instruction chain with ~34% compliance.
Changes: `.claude/rules/` (3 files auto-loaded), AGENTS.md self-contained with rules
inline, condensed rules in Cursor/Windsurf/Copilot configs, pre-commit hook blocks
commits without CHANGELOG/TIME_LOG, Stop hook verifies task-completion, 10 skill-wiring
gaps fixed across 7 workflows. 45 files changed.

## 2026-04-16 — v1.36: fix sync-skeleton cd .memory directory bleed

Step 5 used `cd .memory && git ... && cd ..`. Bash tool persists CWD between
calls — if cd + push are in one call, the next call starts inside .memory/ on
the ai-memory branch, causing `gh pr create` to open PRs from ai-memory instead
of the project branch. Fixed by replacing all `cd .memory` / `cd ..` with
`git -C .memory` throughout Step 5. Added explicit warning callout block.
Files: roles/dev/workflows/sync-skeleton.md, .agents/workflows/sync-skeleton.md.
Note: Bug 2 (pre-commit hook worktree detection) was already fixed in v1.35.
Downstream projects need sync-skeleton run to receive both fixes.

## 2026-04-16 — v1.35: fix pre-commit hook worktree detection

Bug: pre-commit-check.sh used `git branch --show-current` at project root, which always
returns `main` — so `.memory/` commits (ai-memory branch) were never skipped by the guard.
Fix: three-pronged detection — check project root branch, check `.memory` worktree branch
via `git -C .memory branch --show-current`, and grep commit command string for `.memory`.
Files: .claude/hooks/pre-commit-check.sh, core/claude-hooks/pre-commit-check.sh.
Also corrected CONFIG.md Skeleton Version 1.33 → 1.34 (was stale from previous session).

## 2026-04-12 — v1.31: refactor-code + CSO fixes + session-start mandate

Added refactor-code workflow (4-phase safe restructure with test safety net gate).
Sharpened CSO descriptions for systematic-debugger (techniques vs process) and
domain-expert (removed [TODO] placeholder). Wired task-planner into develop-feature
Phase 1. Fixed session-start mandate missing from tool config files — Claude Code,
Cursor, Copilot, and Windsurf all load their config eagerly but read AGENTS.md
lazily, so the mandate was never seen. Added "Session Start — MANDATORY" block
directly to all 5 tool config files and their core/ templates. sync-skeleton
propagates this to downstream projects automatically.
Files: core/CLAUDE.md.template, core/GEMINI.md.template, core/cursor-rule.mdc.template,
core/copilot-instructions.md.template, core/windsurf-rule.md.template + installed copies.

## 2026-04-11 — v1.30: brainstorm, TDD, systematic-debugger, git-worktrees

Added 2 workflows (brainstorm-feature, debug-issue), 3 skills (test-driven-development,
systematic-debugger, using-git-worktrees). Patched develop-feature Phase 2 with TDD
recommendation. git-flow gained worktree quick-reference. Bumped VERSION to 1.30,
CONFIG.md Skeleton Version to 1.30. All self-sync locations updated including
roles/dev/workflows/ and roles/dev/skills/ sources.

## 2026-03-19 — Initial agentic setup via setup-skeleton workflow

Installed agentskel on itself (dogfooding). Created memory files, .agents/ structure
with rules, all 13 workflows, 5 standards, 8 skills, CLAUDE.md, GEMINI.md,
.claudeignore, CODEOWNERS, and install-agent.sh.
