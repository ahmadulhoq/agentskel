# agentskel Changelog

## v1.2 — 2026-03-24

### Workflows — Blueprint creation
- Added `create-blueprint` workflow: step-by-step setup for a new blueprint repo
  (shared domain knowledge for multi-project teams)
- Creates: `specs/` (domain spec stubs), `parity/PARITY_MATRIX.md`,
  `bus/` (knowledge bus with entry template), `skills/domain-expert/`
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
- Blueprint = optional team domain knowledge repo (specs, parity, bus, domain skills)
- `[SKELETON_PATH]` for framework templates, `[BLUEPRINT_PATH]` for domain knowledge
- Symlink pattern for skeleton/blueprint repos, copies for downstream projects
- agentskel self-installs its own pattern (`.agents/rules/` symlinks to `core/rules/`)
