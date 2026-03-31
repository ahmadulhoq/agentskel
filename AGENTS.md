# agentskel Framework — Agent Instructions

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
| session-start | Session initialization — memory check, file reading, version checks, alerts | `.agents/skills/session-start/SKILL.md` |
| task-completion | Post-task checklist — CHANGELOG, TIME_LOG, SYMBOLS/MAP, RESUME, memory commit | `.agents/skills/task-completion/SKILL.md` |
| git-flow | Git branching, commit, and PR procedures | `.agents/skills/git-flow/SKILL.md` |
| senior-developer | Code quality, SOLID principles, design philosophy, platform standards | `.agents/skills/senior-developer/SKILL.md` |
| code-reviewer | PR review against standards and sacred behaviors | `.agents/skills/code-reviewer/SKILL.md` |
| test-engineer | Test strategy, coverage analysis, test writing | `.agents/skills/test-engineer/SKILL.md` |
| task-planner | Feature decomposition and task tracking | `.agents/skills/task-planner/SKILL.md` |
| domain-expert | Project-specific business logic expertise | `.agents/skills/domain-expert/SKILL.md` |
| skill-authoring | When creating a new skill/workflow or improving an existing skill's effectiveness | `.agents/skills/skill-authoring/SKILL.md` |

## Workflows
| Workflow | Description | Path |
|----------|-------------|------|
| cartographer | When codebase structure has changed, MAP.md/SYMBOLS.md are missing or stale, or after major refactors | `.agents/workflows/cartographer.md` |
| develop-feature | When implementing a new feature end-to-end requiring planning, branch, implementation, testing, PR | `.agents/workflows/develop-feature.md` |
| implement-task | Generic wrapper for any ad-hoc task (default when no named workflow matches) | `.agents/workflows/implement-task.md` |
| fix-tech-debt | Pick a debt item, fix it, update registry | `.agents/workflows/fix-tech-debt.md` |
| hotfix | Emergency fix with expedited flow | `.agents/workflows/hotfix.md` |
| cut-release | When the team is ready to ship a new version — bumps, changelog, dependency snapshot | `.agents/workflows/cut-release.md` |
| check-dependencies | When dependency versions need auditing or Last Dependency Check is overdue (14-day cadence) | `.agents/workflows/check-dependencies.md` |
| sync-versions | When actual dependency versions may have drifted from VERSIONS.md — run after upgrades | `.agents/workflows/sync-versions.md` |
| update-conventions | When coding conventions may have drifted from practice or Last Conventions Check is overdue (90 days) | `.agents/workflows/update-conventions.md` |
| janitor | When Knowledge Bus entries are older than 30 days or memory files have stale content | `.agents/workflows/janitor.md` |
| setup-skeleton | When setting up agentskel on a project for the first time — run once per project | `.agents/workflows/setup-skeleton.md` |
| sync-skeleton | When skeleton version in CONFIG.md is behind current agentskel VERSION | `.agents/workflows/sync-skeleton.md` |
| check-skeleton | Detect version gap between project and skeleton | `.agents/workflows/check-skeleton.md` |
| create-blueprint | When a team needs a central domain knowledge repo for multi-platform projects | `.agents/workflows/create-blueprint.md` |
| parity-check | When checking feature parity across platforms after shipping or on scheduled cadence | `.agents/workflows/parity-check.md` |

## Memory
Persistent project memory lives in `.memory/`. The `session-start` procedure reads all
memory files — do not read them individually, run the procedure.
