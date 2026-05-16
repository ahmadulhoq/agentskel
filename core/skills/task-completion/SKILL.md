---
name: task-completion
license: MIT
description: Post-task checklist for CHANGELOG, TIME_LOG, SYMBOLS/MAP, RESUME, and memory commits. Execute after completing a task that modified files outside `.memory/`. Do NOT run for pure discussion, memory-only maintenance, or skeleton syncs.
---

# Task Completion Checklist

**A task is NOT complete until every applicable item below is done.
Execute this immediately after the last implementation step — before responding
to the user or starting anything else.**

## Step 0 — Applicability Gate

- [ ] Run `git status --porcelain` in the repo root.
- [ ] If the only changed paths are inside `.memory/`, or there are no changes at all → **STOP**. This is not a development task (pure discussion, read-only analysis, memory-only maintenance). Do not run the steps below. Respond to the user directly.
- [ ] **Exception:** if a workflow invoked this skill explicitly (e.g. `publish-adr` or `publish-postmortem` after a Confluence publish with no local file changes) — proceed through every step regardless. The workflow knows it did real work.

## Step 1 — CHANGELOG

- [ ] Add an entry to `.memory/CHANGELOG.md` describing what changed and why.
- [ ] **Skeleton repos only:** if the change touches any workflow or skill file,
      append `affected: name, name, ...` at the end of the entry (both
      `CHANGELOG.md` and `.memory/CHANGELOG.md`). Omit if no workflow/skill changed.
      See `references/skeleton-contribution-checklist.md` for the full rule.
- Skip only if zero files were modified (e.g. pure analysis tasks).

## Step 2 — SYMBOLS / MAP

- [ ] If any class or function was created, renamed, or deleted →
      update the relevant symbol file. Split mode: update
      `symbols/[module].md` and the SYMBOLS.md index counts.
      Single-file mode: update the module section in SYMBOLS.md.
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
      read and execute `references/skeleton-contribution-checklist.md`.
- Skip entirely for downstream projects (Skeleton Path ≠ `.`).

## Step 6 — RESUME.md and BACKLOG.md

### 6a — RESUME.md
- [ ] Update `.memory/RESUME.md` with:
  - Task outcome (what was done)
  - Current status
  - Any follow-up work needed
- [ ] If no more tasks are pending, set Status to IDLE.

### 6b — BACKLOG.md (if `.memory/BACKLOG.md` exists)
- [ ] If this task was tracked in BACKLOG.md, move its row to the Done section.
      Cap Done at 5 entries — drop the oldest if needed.
- [ ] If `RESUME.md` Next Task is now empty and BACKLOG.md has P0 or P1 items,
      pull the highest-priority item into `RESUME.md` Next Task.
- [ ] When adding a new item to BACKLOG.md: if Jira is configured
      (`jira` in Supported Tools in CONFIG.md), prompt the user for the Jira ticket key
      and populate the `Jira Ticket` column. Leave blank if no ticket exists — this
      marks the item as a local intention not yet planned in Jira.
- Skip if BACKLOG.md does not exist (pre-v1.51.0 project — remind user to run sync-skeleton).

### 6c — Discussion resume check
- [ ] Read `.memory/RESUME.md` Session Notes.
- [ ] If any `DISCUSSION PAUSED:` entries exist → invoke the `discussion-continuity`
      skill (Operation B) to resurface the discussion before ending this response.
      Re-ask the open gate question explicitly. Do NOT skip this — a paused
      discussion means the user is waiting for a continuation, not a task summary.
- Skip if Session Notes has no `DISCUSSION PAUSED:` entries.

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
