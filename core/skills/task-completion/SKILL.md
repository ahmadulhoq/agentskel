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
- Skip if no blueprint is configured, or if the change is purely project-specific.

## Step 5 — Migration Step (skeleton/agentskel repos only)

- [ ] If this task bumped `agent-hq/VERSION` with a **breaking change** (MAJOR version) →
      ensure a corresponding migration step exists in `sync-skeleton.md`.
- [ ] The migration step must include exact commands and file changes needed for
      downstream projects to adopt the breaking change.
- **This is mandatory for breaking changes. Without it, downstream syncs will fail.**
- Skip if this is not the agentskel repo, or if the VERSION bump is non-breaking.

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

---

**Gate:** Do not respond to the user or start the next task until all applicable
steps above are checked off. If a step was skipped, note why.
