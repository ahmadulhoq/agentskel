---
name: implement-task
description: Generic wrapper for any ad-hoc implementation request that doesn't
  match a specific workflow (develop-feature, fix-tech-debt, hotfix). Ensures
  pre-flight, planning, and task-completion happen for every task — not just
  named workflows.
---

# Implement Task Workflow

## When to Use
- The user asks you to implement, fix, change, add, remove, or refactor something
- The request does NOT match a more specific workflow:
  - **develop-feature** — full feature with ticket/tracking
  - **fix-tech-debt** — catalogued debt item from TECH_DEBT.md
  - **hotfix** — production emergency
- If in doubt, use this workflow. It's better to follow a lightweight checklist
  than to work without one.

## Pre-Flight
1. Read `.memory/RULES.md`, `.memory/MAP.md`, `.memory/SYMBOLS.md`.
2. Read `.memory/RESUME.md` if continuing previous work.
3. Read `.memory/LESSONS.md` and `.memory/SACRED.md`.
4. Understand the request fully. Ask clarifying questions if needed.

## Phase 1: Plan
5. Write a plan (scale it to the task — one paragraph for small changes,
   full breakdown for complex ones). Include:
   - Files to modify
   - Approach and risks
   - **Estimated human effort** (how long a senior dev would take)
6. Present the plan to the user. **Wait for explicit approval before
   writing any code.** No exceptions — every task requires approval.

## Phase 1b: Branch
7. Create the branch following the **`git-flow`** skill before writing
   any code:
   ```
   git checkout [DEFAULT_BRANCH] && git pull && git checkout -b <branch-name>
   ```

## Phase 2: Implement
8. Follow `developer` skill standards for all code.
9. Match existing file style for edits.
10. Respect all SACRED.md entries.
11. Checkpoint to RESUME.md after each sub-task (for multi-step work).

## Phase 3: Verify
12. Follow `test-engineer` skill standards.
13. Run tests for affected modules (if tests exist).
14. Run the repo's static analysis tool if available.
15. For changes without automated tests, verify correctness manually and
    describe what you checked.

## Phase 4: Complete

16. Commit and open a PR following the **`git-flow`** skill.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, execute the
**`task-completion`** skill (`.agents/skills/task-completion/SKILL.md`).
This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
