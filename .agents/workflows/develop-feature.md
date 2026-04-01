---
name: develop-feature
description: When the user asks to implement a new feature end-to-end requiring
  planning, branch creation, implementation, testing, and PR. Use for work that
  goes beyond a simple fix or ad-hoc task.
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

## Phase 1: Plan
6. Write a plan with checkable items. Include:
   - Files to create or modify
   - Dependencies and risks
   - Testing approach
   - Any SACRED.md entries that might be affected
   - **Estimated human effort** (how long a senior dev would take manually)
7. Present the plan to the user. Wait for approval.
8. Record the task start time.

## Phase 2: Implement
9. Follow `developer` skill standards for all code.
10. Match existing file style for edits. Use STYLE_GUIDE.md for new files.
11. Respect all SACRED.md entries. Flag if a sacred behavior must change.
12. Update `.memory/SYMBOLS.md` for any new public classes/functions.
13. Update `.memory/MAP.md` if architecture changes.
14. Checkpoint to RESUME.md after each sub-task.

## Phase 3: Test & Verify
15. Follow `test-engineer` skill standards.
16. Write unit tests for all new logic.
17. Run tests and verify they pass.
18. If the repo has a static analysis tool configured, run it and fix violations
    before opening a PR.

## Phase 4: Document & Ship
19. Update relevant documentation.
20. Log the change in `.memory/CHANGELOG.md`.
21. If this affects other platforms and a blueprint is configured
    (`Blueprint Path` in `.memory/CONFIG.md`), create a Knowledge Bus entry
    in the blueprint's `bus/` directory.
22. Write a walkthrough summarising what was done.
23. **Record the task in `.memory/TIME_LOG.md`** with estimated human hours,
    agent start/end times, duration, and files changed.
24. Commit and push all `.memory/` changes:
    `cd .memory && git add -A && git commit -m "agent: completed [task summary]" && git push origin ai-memory`
25. Push the feature branch and open a PR to `development`:
    - PR title: `[TICKET-XXXX] short description` or `[DEBT-ID] short description`
    - PR body: what changed, why, how to test, risk level
    - **Do NOT merge** — a human reviewer must approve
26. Set RESUME.md Status to IDLE.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
