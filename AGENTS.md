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

## Workflows
| Workflow | Description | Path |
|----------|-------------|------|
| cartographer | Map modules, classes, functions into memory | `.agents/workflows/cartographer.md` |
| develop-feature | Full feature development with planning, implementation, testing | `.agents/workflows/develop-feature.md` |
| implement-task | Generic wrapper for any ad-hoc task (default when no named workflow matches) | `.agents/workflows/implement-task.md` |
| fix-tech-debt | Pick a debt item, fix it, update registry | `.agents/workflows/fix-tech-debt.md` |
| hotfix | Emergency fix with expedited flow | `.agents/workflows/hotfix.md` |
| cut-release | Version bump, changelog, dependency snapshot | `.agents/workflows/cut-release.md` |
| check-dependencies | Scan for outdated/vulnerable dependencies | `.agents/workflows/check-dependencies.md` |
| sync-versions | Keep VERSIONS.md in sync with actual version files | `.agents/workflows/sync-versions.md` |
| update-conventions | Refresh CONVENTIONS.md from official sources | `.agents/workflows/update-conventions.md` |
| janitor | Monthly cleanup of stale memory, dead code, tech debt | `.agents/workflows/janitor.md` |
| setup-skeleton | One-time install of agentskel on a new project | `.agents/workflows/setup-skeleton.md` |
| sync-skeleton | Update project when agentskel has new changes | `.agents/workflows/sync-skeleton.md` |
| check-skeleton | Detect version gap between project and skeleton | `.agents/workflows/check-skeleton.md` |
| create-blueprint | Set up shared domain knowledge repo for multi-project teams | `.agents/workflows/create-blueprint.md` |
| parity-check | Cross-platform feature consistency audit | `.agents/workflows/parity-check.md` |

## Memory
Persistent project memory lives in `.memory/`. The `session-start` procedure reads all
memory files — do not read them individually, run the procedure.
