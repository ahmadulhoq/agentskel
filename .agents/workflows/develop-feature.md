---
name: develop-feature
description: When the user asks to implement a new feature end-to-end requiring planning, branch creation, implementation, testing, and PR. Use for work that goes beyond a simple fix or ad-hoc task.
---

# Feature Development Workflow

## Pre-Flight
1. Read `.memory/RULES.md`, `.memory/MAP.md`, `.memory/SYMBOLS.md`.
2. Read `.memory/RESUME.md` if continuing previous work.
3. Read `.memory/LESSONS.md`, `.memory/SACRED.md`, and `.memory/VERSIONS.md`.
4. Understand the requirement fully. Ask clarifying questions.
   If the task involves any version, dependency, or toolchain file,
   read the release notes for the target version before planning.
   Follow the project's dependency management standard
   for upgrade tier rules and approval requirements.
5. Create the branch before writing any code:
   - Ticket given: `TICKET-XXXX-kebab-description`
   - Tech debt fix: `debt-id-kebab-description`
   ```
   git checkout development && git pull && git checkout -b <branch-name>
   ```

## Phase 0: Ticket Routing
If this task originated from a Jira ticket (user mentioned a ticket key like `PROJ-1234`),
use the `implement-from-ticket` workflow instead. If not from a ticket, continue.

## Phase 1: Plan
6. Use the `task-planner` skill to decompose the work.
   Use `codebase-navigator` skill to find relevant code via MAP.md/SYMBOLS.md before planning.
   Write a plan with checkable items. Include:
   - Files to create or modify
   - Dependencies and risks
   - Testing approach
   - Any SACRED.md entries that might be affected
   - **Estimated human effort** (how long a senior dev would take manually)
7. For large features with independent subtasks, use `subagent-dispatch` to parallelize implementation.
8. Present the plan to the user. Wait for explicit approval before proceeding to Phase 2.
   **Concerns and tradeoffs alone are not a plan.** A plan must state: (1) proposed
   approach, (2) files to modify, (3) open decision points. Do not proceed without
   an explicit "yes" or equivalent.
9. Record the task start time.

## Phase 2: Implement
9. Follow `developer` skill standards for all code.
10. Match existing file style for edits. Use STYLE_GUIDE.md for new files.
11. Respect all SACRED.md entries. Flag if a sacred behavior must change.
12. **TDD is highly recommended** for all logic changes. For each behavior unit:
    - Use the `test-driven-development` skill (RED → GREEN → REFACTOR cycle).
    - Write the failing test first. Confirm it fails before writing production code.
    - Skip only for trivial config/boilerplate — document the exemption reason.
13. Update `.memory/SYMBOLS.md` for any new public classes/functions.
14. Update `.memory/MAP.md` if architecture changes.
15. Checkpoint to RESUME.md after each sub-task.

## Phase 3: Test & Verify
16. Follow `test-engineer` skill standards.
17. Write unit tests for all new logic (covered by TDD above if followed).
18. Run tests and verify they pass.
19. If the repo has a static analysis tool configured, run it and fix violations
    before opening a PR.

## Phase 4: Document & Ship
20. Before committing, dispatch a review subagent via `subagent-dispatch`:
    "Review changes against the plan. Read .memory/SACRED.md and .memory/CONVENTIONS.md.
    Report issues." Address any findings before proceeding.
21. Follow `git-flow` skill for commit and PR procedures.
21. Update relevant documentation.
21. Log the change in `.memory/CHANGELOG.md`.
22. If this affects other platforms and a blueprint is configured
    (`Blueprint Path` in `.memory/CONFIG.md`), create a Knowledge Bus entry
    in the blueprint's `bus/` directory.
23. Write a walkthrough summarising what was done.
24. **Record the task in `.memory/TIME_LOG.md`** with estimated human hours,
    agent start/end times, duration, and files changed.
25. Commit and push all `.memory/` changes:
    `cd .memory && git add -A && git commit -m "agent: completed [task summary]" && git push origin ai-memory`
26. Push the feature branch and open a PR to `development`:
    - PR title: `[TICKET-XXXX] short description` or `[DEBT-ID] short description`
    - PR body: what changed, why, how to test, risk level
    - **Do NOT merge** — a human reviewer must approve
26b. **Atlassian integration (conditional).** If `.memory/JIRA_WORKFLOW.md` exists and
     the task referenced a ticket:
     - Use `atlassian-integration` skill to transition the ticket per JIRA_WORKFLOW.md
       ('PR opened' event, if auto-apply is yes).
     - Add comment on ticket with PR URL.
     - After merge (separate invocation): transition per 'PR merged' event, reassign
       to QA owner from TEAM.md if handoff rule says so.
27. Set RESUME.md Status to IDLE.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
