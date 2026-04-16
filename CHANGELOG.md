# Agent Changelog: agentskel

<!-- Log every change with description and reasoning.
     Format: ## [DATE] — [Short Description]
     Include: what changed, why, files affected, any risks. -->

## 2026-04-17 — Context load analysis: session-start optimization findings

Measured startup cost: ~880 lines (small project), ~1,300 lines (large project).
Analysed all 10 memory files for actual usage across every workflow.

Safe optimizations identified:
- VERSIONS.md: remove from session-start Step 2 (saves 44-194 lines). Session-start
  only checks CONFIG.md timestamp; workflows load VERSIONS.md when needed.
- RESUME.md: skip Previously Completed + Cartography State sections (saves ~25 lines).
  Only cartographer needs full RESUME.
- NEEDS_REVIEW.md: check line count first, skip if empty (saves 0-13 lines).

Rejected optimizations (would break workflows):
- MAP.md partial read — Critical Business Logic Flows section is essential for bug
  fixes (contains sacred constraints, cross-module data flows). 320 lines is the
  cost of architecture knowledge.
- LESSONS.md deferred — compliance risk; agents won't load things they're told to
  load on-demand. Keep at 27 lines in session-start.
- Session-start skill drop — Claude Code keeps invoked skills in context by design.

Honest saving: 5-18% for large projects, not the 37% originally claimed.

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
