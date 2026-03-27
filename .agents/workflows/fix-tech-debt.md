---
name: fix-tech-debt
description: Systematic resolution of catalogued tech debt items from TECH_DEBT.md.
  Use when assigned a specific debt ID (AP-XXX, BUG-XXX, SI-XXX, etc.).
---

# Tech Debt Fix Workflow

## When to Use
- When assigned a specific debt ID (e.g. `AP-033`, `BUG-009`, `SI-002`)
- Only after a tech lead has approved the item for resolution in this cycle
- One debt item per branch — do not batch unrelated items

## Pre-Flight
1. Read `.memory/RULES.md`, `.memory/MAP.md`, `.memory/SYMBOLS.md`.
2. Read `.memory/RESUME.md` if continuing previous work.
3. Read `.memory/LESSONS.md`, `.memory/SACRED.md`, and `.memory/VERSIONS.md`.
4. Read the specific TECH_DEBT.md entry. Understand the root cause, not just the symptom.
   Read the source file(s) listed in the entry before planning anything.
5. Create the branch:
   ```
   git checkout development && git pull && git checkout -b <debt-id>-<kebab-description>
   ```
   Example: `ap-033-appsettings-god-class`, `bug-009-toggle-wrong-livedata`

## Phase 1: Plan
6. Write a plan with checkable items. Include:
   - Root cause analysis
   - Files affected and expected scope of change
   - Risks and side effects (what might break)
   - Testing approach to prove the fix is correct and nothing regressed
   - **Estimated human effort** (how long a senior dev would take manually)
7. Present the plan to the user. Wait for approval before writing any code.
8. Record the task start time.

## Phase 2: Fix
9. Follow `senior-developer` skill standards for all code.
10. Fix the root cause — not just the surface symptom.
11. Keep scope tight. If you discover adjacent debt during the fix, log it in
    TECH_DEBT.md and address it in a separate PR. Do not expand the current branch.
12. Checkpoint to RESUME.md after each sub-task.

## Phase 3: Test & Verify
13. Follow `test-engineer` skill standards.
14. Write a regression test that would have caught this debt item originally.
15. Run tests for affected modules.
16. Run the repo's static analysis tool and fix all violations.

## Phase 4: Document & Ship
17. Update TECH_DEBT.md: mark the item `Status: RESOLVED`, add resolution date and notes.
18. If SYMBOLS.md or MAP.md changed (renamed/moved/deleted classes), update them.
19. Log the change in `.memory/CHANGELOG.md`.
20. **Record the task in `.memory/TIME_LOG.md`** with estimated human hours,
    agent start/end times, duration, and files changed.
21. Commit and push all `.memory/` changes:
    `cd .memory && git add -A && git commit -m "agent: resolved [DEBT-ID]" && git push origin ai-memory`
22. Push the branch and open a PR to `development`:
    - PR title: `[DEBT-ID] short description`
    - PR body: root cause, fix approach, risk level, test evidence
    - **Do NOT merge** — a human reviewer must approve
23. Set RESUME.md Status to IDLE.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
