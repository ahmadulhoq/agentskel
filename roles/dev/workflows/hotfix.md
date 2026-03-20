---
name: hotfix
description: Fast-path workflow for production bugs that cannot wait for the
  normal release cycle. Requires explicit tech lead sign-off before branching.
---

# Hotfix Workflow

## When to Use
- A production bug is confirmed (data loss, crash affecting significant user %, critical feature broken)
- Severity is HIGH or CRITICAL
- The fix cannot wait for the next scheduled release

**Do NOT use this for minor bugs or improvements. Use `develop-feature` instead.**

## Pre-Flight
1. **Confirm with the tech lead** that a hotfix is warranted. Do not start without explicit approval.
2. Read `.memory/RULES.md`, `.memory/MAP.md`, `.memory/SYMBOLS.md`.
3. Read `.memory/LESSONS.md` and `.memory/SACRED.md`.
4. Identify or create the tracking ticket. All hotfixes must be tracked.

## Phase 1: Branch & Diagnose
5. Branch from `main` (production), not `development`:
   ```
   git checkout main && git pull && git checkout -b hotfix/TICKET-XXXX-kebab-description
   ```
6. Reproduce the bug locally before writing any fix.
7. Identify the root cause. Write a clear diagnosis — this goes in the PR body.
8. Present diagnosis and proposed fix to the tech lead. Get explicit approval.
9. Record the task start time.

## Phase 2: Fix (Minimal Scope)
10. Fix ONLY the reported bug. Do not refactor, clean up, or improve surrounding code.
    Hotfixes must be as small as possible — every extra line is extra risk in production.
11. Checkpoint to RESUME.md.

## Phase 3: Test & Verify
12. Write a regression test that proves the bug is fixed and won't regress.
13. Run tests for affected modules.
14. Run the repo's static analysis tool and fix all violations.

## Phase 4: Ship & Backport
15. Log the change in `.memory/CHANGELOG.md`.
16. **Record the task in `.memory/TIME_LOG.md`**.
17. Commit and push all `.memory/` changes:
    `cd .memory && git add -A && git commit -m "agent: hotfix [TICKET-XXXX]" && git push origin ai-memory`
18. Push the hotfix branch and open a PR to `main`:
    - PR title: `[TICKET-XXXX] hotfix: short description`
    - PR body: bug reproduction steps, root cause, fix, regression test evidence, risk level
    - **Do NOT merge** — requires tech lead approval + CI pass
19. After the `main` PR is merged, backport to `development`:
    ```
    git checkout development && git pull
    git checkout -b backport/TICKET-XXXX-to-development
    git cherry-pick <hotfix-commit-sha>
    ```
    Open PR: `[TICKET-XXXX] backport hotfix to development`
20. Set RESUME.md Status to IDLE.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
