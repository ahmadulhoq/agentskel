---
name: task-completion
description: Post-task checklist for documentation, time logging, and memory updates.
  Must be executed immediately after completing any development task — before
  responding to the user or starting the next task.
---

# Task Completion Checklist

**A task is NOT complete until every applicable item below is done.
Execute this immediately after the last implementation step — before responding
to the user or starting anything else.**

## Step 1 — CHANGELOG

- [ ] Add an entry to `.memory/CHANGELOG.md` describing what changed and why.
- Skip only if zero files were modified (e.g. pure analysis tasks).

## Step 2 — SYMBOLS / MAP

- [ ] If any public class or function was created, renamed, or deleted →
      update `.memory/SYMBOLS.md`.
- [ ] If a module was added or architecture changed → update `.memory/MAP.md`.
- Skip only if no structural changes were made.

## Step 3 — TIME_LOG

- [ ] If this was a development task (feature, tech debt fix, hotfix), record it in
      `.memory/TIME_LOG.md` with:
  - Task ID (ticket ID or DEBT-ID)
  - Date
  - Estimated human hours (from the plan)
  - Agent start and end time
  - Agent duration
  - Files changed (count and list)
  - Status (completed / partial / blocked)
- **This step is mandatory for all development tasks. Not optional.**

## Step 4 — Knowledge Bus (if blueprint configured)

- [ ] If this change affects cross-platform contracts or shared business logic,
      **and** the project has a `Blueprint Path` in `.memory/CONFIG.md` →
      create a Knowledge Bus entry in the blueprint's `bus/` directory.
- [ ] After creating the bus entry, commit and push it to the blueprint repo:
      ```bash
      git -C [BLUEPRINT_PATH] add bus/ && \
      git -C [BLUEPRINT_PATH] commit -m "bus: [short description] from [PLATFORM] agent" && \
      git -C [BLUEPRINT_PATH] push origin [BLUEPRINT_DEFAULT_BRANCH]
      ```
      If the push fails (e.g. merge conflict), warn the user — do not force-push.
      The bus entry exists locally and will be picked up on the next manual push.
- Skip if no blueprint is configured, or if the change is purely project-specific.

## Step 5 — Skeleton Contribution (skeleton repos only)

- [ ] If `Skeleton Path` in `.memory/CONFIG.md` is `.` (this IS the skeleton repo),
      read and execute `skeleton-contribution-checklist.md` (in the same directory
      as this skill).
- Skip entirely for downstream projects (Skeleton Path ≠ `.`).

## Step 6 — RESUME.md

- [ ] Update `.memory/RESUME.md` with:
  - Task outcome (what was done)
  - Current status
  - Any follow-up work needed
- [ ] If no more tasks are pending, set Status to IDLE.

## Step 7 — Memory commit

- [ ] Commit all `.memory/` changes to the ai-memory branch:
  ```
  cd .memory && git add -A && git commit -m "agent: completed [task summary]" && git push origin ai-memory
  ```
- RESUME.md is excluded from commits (it is local-only via .gitignore on ai-memory).

## Step 8 — Completion summary

Before responding to the user, state:
- **Steps executed:** [list each step that was run]
- **Steps skipped:** [list each step that was skipped, with a one-line reason]

This makes skip decisions visible to the user for review. Do not omit this step.

---

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "This was a tiny change, no CHANGELOG needed" | If files were modified, CHANGELOG gets an entry. Size doesn't matter. | Write the entry. |
| "TIME_LOG is just bookkeeping, the user doesn't care" | TIME_LOG tracks agent ROI. Skip it and the framework loses its value case. | Always log. |
| "I'll update RESUME later" | There is no later — your context dies when this session ends. | Update now. |
| "No structural changes, I can skip SYMBOLS/MAP" | Did you add a public function? Rename a class? Verify before skipping. | Check, then decide. |
| "The memory commit can wait until end of session" | If the session crashes, uncommitted memory is lost. | Commit after every task. |
| "I already responded to the user" | The gate says: ALL steps BEFORE responding. | Go back and finish. |
| "The completion summary is redundant" | It makes skip decisions visible — a review mechanism, not a status update. | Always include it. |

---

**Gate:** Do not respond to the user or start the next task until all applicable
steps above are checked off and the completion summary is stated.
