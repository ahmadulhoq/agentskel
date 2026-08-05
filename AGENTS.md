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
and functions. See the `codebase-navigator` skill for guidance. Do not grep for things already indexed.

## Core Behavior (always active)

- **Never assume.** Verify before concluding. Read the actual file or code first.
- **Discuss, agree, then execute.** Get explicit approval before implementing.
- **Plan first.** Write a plan, present it, wait for approval. No exceptions.
- **Verify before done.** Run tests, check logs, demonstrate correctness.
- **Minimal impact.** Only touch what's necessary.
- **No laziness.** Find root causes. No temporary fixes.
- **Self-improvement.** After corrections, write a lesson in `.memory/LESSONS.md`.
- **Respect sacred behaviors.** Never modify `.memory/SACRED.md` entries without human approval.
- **If something goes sideways, STOP and re-plan.**
- **No changes during discussion.** Wait for "go ahead" before editing files.
- **No commits without an implementation instruction.**
- **Complete the git flow once started.** Branch → implement → commit → PR without pausing.
- **Sub-agents follow the same rules.**
- **Direct-Commit Mode** — when `Direct-Commit Mode` in `.memory/CONFIG.md` is `on`, or the user prefixed the current request with `direct:`, skip the branch + PR ceremony and commit/push directly to the default branch. Plan-first + task-completion still apply. Surface a `DIRECT-COMMIT MODE ACTIVE — committing directly to <branch> (no PR).` banner before any commit.
- **Autopilot Mode** — when `Autopilot Mode` in `.memory/CONFIG.md` is `on`, the harness auto-approves safe operations (reads, project-scoped writes, non-destructive git/gh) via expanded `permissions.allow` + `pre-bash-safety.sh` hook — so trivial permission prompts don't interrupt work. **Does NOT bypass plan approval, decisions, or concerns.** Still pauses for destructive ops (--force, --hard, branch -D, checkout . or -- file, clean -f, recursive force delete), out-of-project paths, dependency upgrades, sacred behaviors, and significant changes (per v1.65.0 gate). Persistent toggle only. See `docs/AUTONOMY-MODES.md`.
- **Present each PR URL on its own line** in the end-of-turn summary (one per line, format `PR #N: <url>`), not inline/comma-separated.
- **Post-merge cleanup is mandatory** once the user confirms a merge — run the `git-flow` cleanup procedure (checkout default, pull, delete local branch, prune origin, update RESUME) BEFORE any next task.
- **Honor user-specified commit granularity** for the duration of the workflow — if the user says "smaller commits" / "atomic commits" / "commit per file", apply to every commit until the workflow ends, not just the next one. Default when none given: one commit per logical change. Surface chosen granularity in the plan.

## Security — Non-Negotiable

- Hardcoded credentials are strictly forbidden.
- Never read, log, or output API keys, tokens, secrets, or credentials.
- All inputs must be validated and sanitised before processing.
- Never use eval, unsanitised shell calls, or command injection vectors.
- Least privilege for file and process operations.
- Only read/write files within this repository, the skeleton, and the blueprint.
- Never modify signing configs, keystores, or secrets management files.
- Never trust external input directly without validation.

## Project Rules
Read `.agents/rules/repo-rules.md` for project-specific rules.
Read `.memory/RULES.md` for project-specific context.
Read `.memory/RESUME.md` to restore session state.

## Skills
| Skill | Description | Path |
|---|---|---|
| atlassian-integration | When reading or writing to Jira tickets or Confluence pages via MCP tools. Use before any Jira transition, ticket creation, or Confluence page update to avoid common failure modes. | `.agents/skills/atlassian-integration/SKILL.md` |
| code-reviewer | When reviewing a PR, auditing code quality, or validating changes against the project's standards and sacred behaviors. | `.agents/skills/code-reviewer/SKILL.md` |
| codebase-navigator | When searching for code, tracing a bug, or understanding how modules connect. Use before grepping blindly — consult the index first. | `.agents/skills/codebase-navigator/SKILL.md` |
| data-model-mapping | When adding, renaming, or removing a field on a data model that has a mapped counterpart elsewhere — an API/DTO, a database/ORM entity, a serializer, or a cross-platform equivalent model (Android/iOS/Backend). Use whenever a model's fields change, before considering the change complete. | `.agents/skills/data-model-mapping/SKILL.md` |
| database-migration | When writing, reviewing, or running a database schema migration — adding, dropping, or altering tables, columns, indexes, or constraints — with any migration tool (Alembic, Rails, Prisma, Room, Core Data, Flyway, Liquibase, raw SQL). Use before generating a migration file, or when one appears in a diff/PR. | `.agents/skills/database-migration/SKILL.md` |
| developer | When writing, modifying, or reviewing application code. Provides code quality standards, SOLID principles, design philosophy, and platform-specific implementation guidance. | `.agents/skills/developer/SKILL.md` |
| discussion-continuity | When a design discussion or evaluation is interrupted by a task or workflow, or when the user says "present the discussion," "where were we," "show me the discussion," or "resume" — save or resurface the discussion state using Session Notes. | `.agents/skills/discussion-continuity/SKILL.md` |
| domain-expert | "When working on features that require domain knowledge — business rules, terminology, or invariants specific to this project. [Replace this description and the content below with your project's domain.]" | `.agents/skills/domain-expert/SKILL.md` |
| git-flow | Git branching, commit, and PR procedures. Use when creating branches, making commits, or opening pull requests. Enforces branch naming, commit message format, and PR rules. | `.agents/skills/git-flow/SKILL.md` |
| knowledge-routing | When deciding where to store a piece of knowledge (memory files vs Confluence vs Jira). Use when about to document something, capture a lesson, create a ticket, or publish a decision. | `.agents/skills/knowledge-routing/SKILL.md` |
| session-start | Session initialization procedure. Checks memory mount, reads all required memory files, validates skeleton version, checks dependency freshness, and surfaces alerts. Must be executed at the start of every session before any other work. | `.agents/skills/session-start/SKILL.md` |
| skill-authoring | When creating a new skill or workflow, or improving an existing skill's effectiveness. Use when the user asks to add a capability, write a new workflow, or when a skill isn't triggering or being followed reliably. | `.agents/skills/skill-authoring/SKILL.md` |
| subagent-dispatch | When delegating work to a subagent — implementation, review, research, or exploration. Use when a task benefits from a fresh context window, parallel execution, or isolated scope. | `.agents/skills/subagent-dispatch/SKILL.md` |
| systematic-debugger | When applying debugging techniques during any investigation — root cause tracing, bisect, defense-in-depth. Enforces hypothesis-first analysis and prohibits guess-and-check changes. Use standalone or inside the debug-issue workflow. | `.agents/skills/systematic-debugger/SKILL.md` |
| task-completion | Post-task checklist for CHANGELOG, TIME_LOG, SYMBOLS/MAP, RESUME, and memory commits. Execute after completing a task that modified files outside `.memory/`. Do NOT run for pure discussion, memory-only maintenance, or skeleton syncs. | `.agents/skills/task-completion/SKILL.md` |
| task-planner | When decomposing a feature or spec into implementable subtasks, estimating scope, or orchestrating multi-step work across subagents. | `.agents/skills/task-planner/SKILL.md` |
| test-driven-development | When implementing logic changes during develop-feature or implement-task. Use the Red-Green-Refactor cycle to write a failing test before any production code. | `.agents/skills/test-driven-development/SKILL.md` |
| test-engineer | When designing test strategy, analysing coverage, or writing tests outside the TDD cycle. Also use when working with CI pipelines or validating changes end-to-end. | `.agents/skills/test-engineer/SKILL.md` |
| using-git-worktrees | When running long feature implementations, parallel branch work, or build/test scripts that must not interfere with the user's active working directory. Creates isolated execution environments via git worktrees in sibling directories. | `.agents/skills/using-git-worktrees/SKILL.md` |

## Workflows
| Workflow | Description | Path |
|---|---|---|
| add-team-member | When a single new person joins the team. Use when `.memory/TEAM.md` already exists and you need to append one member (with roles, optional module assignments, and optional Jira account ID) without touching the rest of the roster. | `.agents/workflows/add-team-member.md` |
| add-workspace-platform | When adding a new platform (subdir with its own git repo) to an existing workspace dispatcher. Runs setup-skeleton in the subdir and updates the workspace config and dispatcher AGENTS.md. | `.agents/workflows/add-workspace-platform.md` |
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
| implement-from-ticket | When the user asks to implement a specific Jira ticket (e.g. "Implement PROJ-1234"). Use when taking a ticket from backlog to merged PR, with automatic status transitions and QA handoff. | `.agents/workflows/implement-from-ticket.md` |
| implement-task | Generic wrapper for any ad-hoc implementation request that doesn't match a specific workflow (develop-feature, fix-tech-debt, hotfix). Ensures pre-flight, planning, and task-completion happen for every task — not just named workflows. | `.agents/workflows/implement-task.md` |
| janitor | When Knowledge Bus entries are older than 30 days, or memory files have accumulated stale content. Run monthly or when bus/ is cluttered. | `.agents/workflows/janitor.md` |
| parity-check | When checking feature parity across platforms after shipping a feature, receiving a Knowledge Bus alert, or on a scheduled cadence. Requires a blueprint with a parity matrix. | `.agents/workflows/parity-check.md` |
| publish-adr | When the user has made an architectural decision that needs to be recorded. Use when ending a brainstorm session or finishing `develop-feature` Phase 1 with a significant architectural choice that should be written up as an ADR, published to Confluence, and cross-linked from LESSONS.md. | `.agents/workflows/publish-adr.md` |
| publish-postmortem | When a production incident has been resolved and needs a written post-mortem. Use after the `hotfix` workflow completes, to publish a structured post-mortem to Confluence, optionally create Jira tickets for action items, and cross-link findings from LESSONS.md. | `.agents/workflows/publish-postmortem.md` |
| refactor-code | When restructuring, renaming, or reorganising existing code without changing its external behavior. Use instead of develop-feature when no new functionality is being added. | `.agents/workflows/refactor-code.md` |
| remove-team-member | When someone leaves the team or rotates off the project. Use when you need to mark a member inactive (or delete them outright) in `.memory/TEAM.md` and reassign any ownership or escalation responsibilities they held. | `.agents/workflows/remove-team-member.md` |
| remove-workspace-platform | When removing a platform from the workspace dispatcher. Does NOT delete the subdir or its agentskel install — only unregisters it from workspace config and AGENTS.md. | `.agents/workflows/remove-workspace-platform.md` |
| setup-confluence | When the user needs to configure Confluence integration for this project. Use when wiring up the Atlassian MCP to .memory/CONFIG.md so ADRs, runbooks, postmortems, and specs can be auto-published to the right space and parent pages. | `.agents/workflows/setup-confluence.md` |
| setup-jira | When the team needs to configure Jira integration for agentskel. Use when populating `.memory/JIRA_WORKFLOW.md` and the Jira section of `.memory/CONFIG.md` by introspecting the Jira project through Atlassian MCP. | `.agents/workflows/setup-jira.md` |
| setup-skeleton | When setting up agentskel on a project for the first time. Run once per project to install memory, rules, skills, workflows, entry points, and standards. | `.agents/workflows/setup-skeleton.md` |
| setup-team | When bootstrapping a project's team roster. Use when `.memory/TEAM.md` has not yet been populated and you need to establish members, roles, ownership, and escalation contacts for the first time. | `.agents/workflows/setup-team.md` |
| setup-workspace | When setting up agentskel as a workspace dispatcher — multiple independent projects under one parent folder, each with its own git repo. Run once at the workspace root to create routing dispatcher files. Does NOT install agentskel in subdirs. | `.agents/workflows/setup-workspace.md` |
| sync-skeleton | When skeleton version in CONFIG.md is behind the current agentskel VERSION. Run by tech lead to apply upstream skeleton improvements to a project. Changes go through a PR — never directly to the default branch. | `.agents/workflows/sync-skeleton.md` |
| sync-team-from-github | When the GitHub team and `.memory/TEAM.md` have drifted. Use when you suspect new joiners, leavers, or rotations have happened on GitHub but `TEAM.md` hasn't been updated, and you want a diff-and-reconcile pass rather than editing member-by-member. | `.agents/workflows/sync-team-from-github.md` |
| sync-versions | When actual project dependency versions may have drifted from VERSIONS.md. Run after dependency upgrades or when VERSIONS.md looks stale. | `.agents/workflows/sync-versions.md` |
| sync-workspace-dispatcher | When workspace dispatcher templates have changed in a newer skeleton version. Regenerates dispatcher files at the workspace root while preserving the workspace name, platforms list, and blueprint path from config. | `.agents/workflows/sync-workspace-dispatcher.md` |
| update-conventions | When project coding conventions may have drifted from actual practice, or Last Conventions Check in CONFIG.md is overdue (90-day cadence). Also run when adopting a new library or framework that needs convention coverage. | `.agents/workflows/update-conventions.md` |
| update-external-skills | Refresh externally-maintained skill packs in the machine-level shared store (~/.agentskel/skills/) and re-link them into the current project. Run when sync-skeleton flags a pack as stale (>=30 days), or manually to pull the latest pack updates. | `.agents/workflows/update-external-skills.md` |
| update-team-member | When an existing team member's roles, ownership, or contact info changes. Use when a member stays on the team but their responsibilities, email, or handle need to be updated without adding or removing anyone. | `.agents/workflows/update-team-member.md` |

## Memory
Persistent project memory lives in `.memory/`. The `session-start` procedure reads all
memory files — do not read them individually, run the procedure.
