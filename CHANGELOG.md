# Agent Changelog: agentskel

<!-- Log every change with description and reasoning.
     Format: ## [DATE] — [Short Description]
     Include: what changed, why, files affected, any risks. -->

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
