# agentskel Framework (shell/markdown) — Agent Instructions

## Non-Negotiable Rules

### Session Start — MANDATORY
Do NOT respond to any user request until you have run the session-start procedure.
Read and follow every step in `.agents/skills/session-start/SKILL.md`.
This loads your memory of the codebase. Without it you will re-scan files unnecessarily,
miss known bugs, repeat past mistakes, and skip required post-task steps.

### Task Completion — MANDATORY
After completing any development task (code change, bug fix, refactor), run the
task-completion procedure BEFORE responding to the user or starting the next task.
Read and follow every step in `.agents/skills/task-completion/SKILL.md`.
Skipping this loses the record of what you did — TIME_LOG, CHANGELOG, RESUME all go stale.

### Git Flow
When creating branches, committing, or opening PRs, follow `.agents/skills/git-flow/SKILL.md`.

### Every Task Follows a Workflow
Route every implementation request to a matching workflow. If no named workflow matches,
use `implement-task` (the default). Do not start coding without a workflow.

### Use Your Memory
When `.memory/MAP.md` and `.memory/SYMBOLS.md` exist, use them to locate modules, classes,
and functions. Do not grep or scan the codebase for things that are already indexed.

## Rules (always active)
Read and follow all rules in `.agents/rules/`.
Read `.memory/RULES.md` for project-specific context and rules.
Read `.memory/RESUME.md` to restore session state and context.

## Skills
| Skill | Description | Path |
|-------|-------------|------|
| code-reviewer | When reviewing a PR, auditing code quality, or validating changes against the project's standards and sacred behaviors. | `.agents/skills/code-reviewer/SKILL.md` |
| codebase-navigator | When searching for code, tracing a bug, or understanding how modules connect. Use before grepping blindly — consult the index first. | `.agents/skills/codebase-navigator/SKILL.md` |
| developer | When writing, modifying, or reviewing application code. Provides code quality standards, SOLID principles, design philosophy, and platform-specific implementation guidance. | `.agents/skills/developer/SKILL.md` |
| domain-expert | "When working on features that require domain knowledge — business rules, terminology, or invariants specific to this project. [Replace this description and the content below with your project's domain.]" | `.agents/skills/domain-expert/SKILL.md` |
| git-flow | Git branching, commit, and PR procedures. Use when creating branches, making commits, or opening pull requests. Enforces branch naming, commit message format, and PR rules. | `.agents/skills/git-flow/SKILL.md` |
| session-start | Session initialization procedure. Checks memory mount, reads all required memory files, validates skeleton version, checks dependency freshness, and surfaces alerts. Must be executed at the start of every session before any other work. | `.agents/skills/session-start/SKILL.md` |
| skill-authoring | When creating a new skill or workflow, or improving an existing skill's effectiveness. Use when the user asks to add a capability, write a new workflow, or when a skill isn't triggering or being followed reliably. | `.agents/skills/skill-authoring/SKILL.md` |
| subagent-dispatch | When delegating work to a subagent — implementation, review, research, or exploration. Use when a task benefits from a fresh context window, parallel execution, or isolated scope. | `.agents/skills/subagent-dispatch/SKILL.md` |
| systematic-debugger | When applying debugging techniques during any investigation — root cause tracing, bisect, defense-in-depth. Enforces hypothesis-first analysis and prohibits guess-and-check changes. Use standalone or inside the debug-issue workflow. | `.agents/skills/systematic-debugger/SKILL.md` |
| task-completion | Post-task checklist for documentation, time logging, and memory updates. Must be executed immediately after completing any development task — before responding to the user or starting the next task. | `.agents/skills/task-completion/SKILL.md` |
| task-planner | When decomposing a feature or spec into implementable subtasks, estimating scope, or orchestrating multi-step work across subagents. | `.agents/skills/task-planner/SKILL.md` |
| test-driven-development | When implementing logic changes during develop-feature or implement-task. Use the Red-Green-Refactor cycle to write a failing test before any production code. | `.agents/skills/test-driven-development/SKILL.md` |
| test-engineer | When designing test strategy, analysing coverage, or writing tests outside the TDD cycle. Also use when working with CI pipelines or validating changes end-to-end. | `.agents/skills/test-engineer/SKILL.md` |
| using-git-worktrees | When running long feature implementations, parallel branch work, or build/test scripts that must not interfere with the user's active working directory. Creates isolated execution environments via git worktrees in sibling directories. | `.agents/skills/using-git-worktrees/SKILL.md` |

## Workflows
| Workflow | Description | Path |
|----------|-------------|------|
| brainstorm-feature | When the user wants to think through a feature idea, explore edge cases, or produce a technical spec before implementation. Use before develop-feature to prevent mid-implementation surprises. | `.agents/workflows/brainstorm-feature.md` |
| cartographer | When codebase structure has changed, MAP.md/SYMBOLS.md are missing or stale, or after major refactors and initial setup. Also run when a new module is added or files are moved between modules. | `.agents/workflows/cartographer.md` |
| check-dependencies | When dependency versions need auditing, Last Dependency Check in CONFIG.md is overdue (14-day cadence), or before starting security-sensitive work. | `.agents/workflows/check-dependencies.md` |
| check-skeleton | Checks whether this project's skeleton version is current. Surfaces the version gap and offers to run sync-skeleton. Run at the start of any session where skeleton drift might have accumulated, or on a scheduled basis. | `.agents/workflows/check-skeleton.md` |
| create-blueprint | When a team manages multiple platform projects sharing business logic and needs a central domain knowledge repo. Run once per organization to set up specs, parity tracking, and the knowledge bus. | `.agents/workflows/create-blueprint.md` |
| cut-release | When the team is ready to ship a new version — version bumps, changelog finalization, dependency snapshots, and CI release trigger. | `.agents/workflows/cut-release.md` |
| debug-issue | When the user reports a bug, an error, or unexpected behavior. Enforces four structured phases — reproduction, failing test, root cause isolation, fix and verify — to stop guess-and-check loops. | `.agents/workflows/debug-issue.md` |
| develop-feature | When the user asks to implement a new feature end-to-end requiring planning, branch creation, implementation, testing, and PR. Use for work that goes beyond a simple fix or ad-hoc task. | `.agents/workflows/develop-feature.md` |
| fix-tech-debt | Systematic resolution of catalogued tech debt items from TECH_DEBT.md. Use when assigned a specific debt ID (AP-XXX, BUG-XXX, SI-XXX, etc.). | `.agents/workflows/fix-tech-debt.md` |
| hotfix | Fast-path workflow for production bugs that cannot wait for the normal release cycle. Requires explicit tech lead sign-off before branching. | `.agents/workflows/hotfix.md` |
| implement-task | Generic wrapper for any ad-hoc implementation request that doesn't match a specific workflow (develop-feature, fix-tech-debt, hotfix). Ensures pre-flight, planning, and task-completion happen for every task — not just named workflows. | `.agents/workflows/implement-task.md` |
| janitor | When Knowledge Bus entries are older than 30 days, or memory files have accumulated stale content. Run monthly or when bus/ is cluttered. | `.agents/workflows/janitor.md` |
| parity-check | When checking feature parity across platforms after shipping a feature, receiving a Knowledge Bus alert, or on a scheduled cadence. Requires a blueprint with a parity matrix. | `.agents/workflows/parity-check.md` |
| refactor-code | When restructuring, renaming, or reorganising existing code without changing its external behavior. Use instead of develop-feature when no new functionality is being added. | `.agents/workflows/refactor-code.md` |
| setup-skeleton | When setting up agentskel on a project for the first time. Run once per project to install memory, rules, skills, workflows, entry points, and standards. | `.agents/workflows/setup-skeleton.md` |
| sync-skeleton | When skeleton version in CONFIG.md is behind the current agentskel VERSION. Run by tech lead to apply upstream skeleton improvements to a project. Changes go through a PR — never directly to the default branch. | `.agents/workflows/sync-skeleton.md` |
| sync-versions | When actual project dependency versions may have drifted from VERSIONS.md. Run after dependency upgrades or when VERSIONS.md looks stale. | `.agents/workflows/sync-versions.md` |
| update-conventions | When project coding conventions may have drifted from actual practice, or Last Conventions Check in CONFIG.md is overdue (90-day cadence). Also run when adopting a new library or framework that needs convention coverage. | `.agents/workflows/update-conventions.md` |

## Memory
Persistent project memory lives in `.memory/`. The `session-start` procedure reads all
memory files — do not read them individually, run the procedure.
