# agentskel Changelog

## v1.7 — 2026-03-25

### Fixes — Spec drift cleanup
- `domain-expert/SKILL.md`: Removed stale reference to "blueprint's
  `skills/domain-expert/SKILL.md`" — blueprints do not include domain-expert
  (create-blueprint workflow explicitly excludes it)
- `README.md`: Fixed standards count in repo structure (was "5 standard
  documents", actually 7)

## v1.6 — 2026-03-25

### Rules — MASTER_PLAN version tracking
- `core-behavior.md`: Added item 4 to Skeleton Contribution checklist — when a change
  affects structure, architecture, or install/sync paths, update `MASTER_PLAN.md` and
  its `Corresponds to:` version marker
- `MASTER_PLAN.md`: Added `Corresponds to: agentskel vX.Y` marker after the title,
  making drift between the ADR and the skeleton version detectable

### Skills — MASTER_PLAN checklist item
- `task-completion`: Added Step 5c (MASTER_PLAN) — update MASTER_PLAN.md per
  MAINTAIN_MASTER_PLAN.md when structure/architecture changes, update the
  `Corresponds to:` version marker to match the new VERSION. Skeleton/agentskel
  repos only.

### Workflows — Blueprint migration steps
- `create-blueprint.md`: Updated sync-skeleton.md trimming notes to include Step 5x
  migration mechanism (adapted for blueprint — migrations go in the sync branch
  commit, not ai-memory). Ensures blueprints created from the template have a
  documented path for breaking-change migrations.

## v1.5 — 2026-03-24

### Workflows — Blueprint trimming rules
- `create-blueprint.md`: added blueprint-specific trimming instructions for all copied files
  — previously said "copy as-is" for files that contain `.memory/`, `ai-memory`, code-testing,
  and session lifecycle references that don't exist in blueprints
- **Rules:** `core-behavior.md` must be trimmed (remove Memory Protocol, Task Completion,
  Skeleton/Blueprint Contribution sections; add Blueprint Identity section)
- **Workflows:** `develop-feature.md` excluded (100% app workflow); `sync-skeleton.md` and
  `check-skeleton.md` must be trimmed (root `CONFIG.md` instead of `.memory/CONFIG.md`,
  no ai-memory commits, no task completion checklist)
- **Standards:** `GIT_WORKFLOW.md` must be simplified for blueprint context (branch naming,
  commits, PRs only — no release/hotfix flows, no AI session protocol)
- **Skills:** `senior-developer` excluded (100% code-focused); `task-planner` must be trimmed
  (remove `.memory/` references, localize Blueprint Check to direct `specs/` paths);
  blueprint-specific `session-start` created (reads root CONFIG.md, checks skeleton version,
  checks git state — no memory mount, no dependency alerts, no freshness dates)
- **CLAUDE.md template:** updated to trigger `session-start` skill for automatic skeleton
  version checking at the start of every session

### Skills — Blueprint skeleton check from downstream projects
- `session-start` (project version): added Step 6b — when a project has a `Blueprint Path`,
  check the blueprint's `CONFIG.md` Skeleton Version against the current skeleton version.
  Surfaces drift as informational (does not block session — sync must be run from the
  blueprint repo directly)

## v1.4 — 2026-03-24

### Workflows — Blueprint skills removal
- `create-blueprint.md`: removed step 4d (blueprint `skills/` directory creation)
  — no agent integration loads skills from `[BLUEPRINT_PATH]/skills/`; all 4 integration
  points (session-start, task-planner, code-reviewer, task-completion) read only from
  `[BLUEPRINT_PATH]/specs/` and `[BLUEPRINT_PATH]/bus/`
- Removed `skills/` from commit, PR body, and post-setup report
- Added clarifying note: domain knowledge lives in `specs/`, not blueprint skills
- Updated v1.2 and v1.0 changelog entries to remove stale `skills/domain-expert/` references

## v1.3 — 2026-03-24

### Workflows — cut-release finalized
- `cut-release.md`: removed DRAFT status, broadened scope from mobile-only to all platforms
- Replaced `[TODO]` markers with `<!-- PLATFORM: X -->` blocks for Android, iOS, Web, Backend
- Pre-flight: platform-specific version file locations (build.gradle, xcconfig, package.json, etc.)
- Step 1: platform-specific CI trigger examples (GitHub Actions, Fastlane)
- Step 5: platform-specific build/deploy trigger examples

### Standards — API Contract completed
- `API_CONTRACT.md`: replaced stub with full standard covering 7 topics:
  URL-prefix versioning, JSON request/response envelope, error format with status code table,
  Bearer token auth, rate limiting headers, cursor-based pagination, breaking change policy
  with 90-day deprecation process
- Includes Agent Rules section for code review and implementation guidance

## v1.2 — 2026-03-24

### Workflows — Blueprint creation
- Added `create-blueprint` workflow: step-by-step setup for a new blueprint repo
  (shared domain knowledge for multi-project teams)
- Creates: `specs/` (domain spec stubs), `parity/PARITY_MATRIX.md`,
  `bus/` (knowledge bus with entry template)
- Lightweight design: no ai-memory branch — blueprint is a knowledge hub managed
  by project-specific agents via `Blueprint Path`
- Includes `.agents/` as safety net with root-level `CONFIG.md` for identity
- 14 workflows total (was 13)

### Workflows — Janitor clarification
- `janitor.md`: clarified that it runs from project context (not blueprint repo);
  project agent reaches into blueprint via `Blueprint Path`

### Skills — Blueprint awareness
- `session-start`: Added Step 6 with two sub-steps:
  - 6a: pull latest blueprint, detect new commits since `Last Blueprint Sync`,
    surface changed specs/parity files to user
  - 6b: check Knowledge Bus for entries targeting this platform
- `domain-expert`: Added `## Blueprint Integration` section — points to
  `[BLUEPRINT_PATH]/specs/` as source of truth for shared business logic
- `code-reviewer`: Added `## Cross-Platform Impact` checklist — verify changes
  match blueprint specs, flag shared logic changes needing bus entries
- `task-planner`: Added `## Blueprint Check` section — read specs and parity
  matrix before planning features that touch shared logic

### Memory — Blueprint sync tracking
- `CONFIG.md` template: Added `Last Blueprint Sync` field to Operational Config;
  updated by session-start after reviewing blueprint changes

## v1.1 — 2026-03-24

### Skills — Platform markers
- `senior-developer`: Added `## Platform Standards` section with Android (Compose/UDF,
  Coroutines, Detekt), iOS (async/await, SwiftUI, SwiftLint), Web (TypeScript, ESLint),
  Backend (generic async/linting) platform markers
- `code-reviewer`: Added platform markers to checklist items 4 (architecture standards),
  5 (lint/static analysis tools), 10 (dependency file references)
- `test-engineer`: Replaced generic Test Structure with platform-marked sections —
  Android (MockK, Espresso, backtick naming), iOS (XCTest, XCUITest),
  Web (Jest/Vitest, Playwright), Backend (standard framework)
- `setup-skeleton` and `sync-skeleton` updated to trim skill platform markers
  (same mechanism as standards)

### Standards — Platform-specific architecture
- Added `ANDROID_ARCHITECTURE.md`: Compose/UDF, Hilt DI, Compose Navigation,
  module graph, data layer patterns (generic template — adapt to project domain)
- Added `IOS_ARCHITECTURE.md`: SwiftUI, NavigationStack, Swift Concurrency,
  SPM module structure, data layer patterns (generic template)
- `setup-skeleton` updated to copy platform-specific standards (Android-only or iOS-only)

## v1.0 — 2026-03-20

Initial release. 2-component architecture: skeleton (agentskel) + optional blueprint
(team domain knowledge).

### Core
- Memory system: ai-memory branch, worktree at `.memory/`, checkpoint protocol
- Procedural skills: session-start, task-completion, git-flow
- Rules: core-behavior, security-non-negotiables, repo-rules convention
- Entry point templates: CLAUDE.md, GEMINI.md
- CONFIG.md: Skeleton Version, Skeleton Path, Blueprint Path (optional),
  Last Skeleton Check, Last Dependency Check, Last Conventions Check

### Role — dev
- 13 workflows: cartographer, check-dependencies, check-skeleton, cut-release,
  develop-feature, fix-tech-debt, hotfix, janitor, parity-check,
  setup-skeleton, sync-skeleton, sync-versions, update-conventions
- 5 standards: architecture, git workflow, style guide, dependency management, API contracts
- Claude Code skill stubs (auto-generated from skills + workflows)
- 8 mission prompts
- Domain skills: senior-developer, test-engineer, code-reviewer, task-planner, domain-expert

### Architecture
- Skeleton = agentskel framework (rules, workflows, skills, standards), installed per project
- Blueprint = optional team domain knowledge repo (specs, parity, bus)
- `[SKELETON_PATH]` for framework templates, `[BLUEPRINT_PATH]` for domain knowledge
- Symlink pattern for skeleton/blueprint repos, copies for downstream projects
- agentskel self-installs its own pattern (`.agents/rules/` symlinks to `core/rules/`)
