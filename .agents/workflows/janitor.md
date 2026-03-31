---
name: janitor
description: When Knowledge Bus entries are older than 30 days, or memory files have
  accumulated stale content. Run monthly or when bus/ is cluttered.
---

# Janitor Workflow

**Trigger:** First session of each month, or when the blueprint's `bus/` contains entries older than 30 days.
**Applies to:** Run from a project that has a blueprint configured. The project agent reaches into the blueprint via `Blueprint Path` to archive bus entries and perform maintenance.
Skip this workflow entirely if no blueprint is configured (`Blueprint Path` not set in `.memory/CONFIG.md`).

---

## Step 1 — Archive Knowledge Bus Entries

1. Resolve the blueprint location via `Blueprint Path` in `.memory/CONFIG.md`.
2. List all files in the blueprint's `bus/` directory (excluding `BUS_ENTRY_TEMPLATE.md` and `archive/`).
3. For each file older than 30 days:
   - Parse the `date:` field from the frontmatter.
   - Append the full entry content to `bus/archive/YYYY-MM.md` (create the file if it does not exist).
   - Delete the original file from `bus/`.
4. Confirm `bus/` contains only current-month entries and the template file.

---

## Step 2 — Review LESSONS.md (per repo)

This step is informational — flag items to the user, do not delete anything.

1. Read `.memory/LESSONS.md` in the active project repo.
2. Flag any lessons older than 6 months that have not been referenced in recent sessions.
3. Present to the user: "These lessons may be candidates for archival. Review and confirm before removing."

---

## Step 3 — Review NEEDS_REVIEW.md (per repo)

1. Read `.memory/NEEDS_REVIEW.md` in the active project repo.
2. If any items are older than 14 days and still unresolved, surface them to the user for classification.
3. All items must move to SACRED.md or TECH_DEBT.md — NEEDS_REVIEW.md should not accumulate indefinitely.

---

## Step 4 — Commit

Commit all changes to the blueprint repo. Since the project agent is working on blueprint files via `[BLUEPRINT_PATH]`, commit from within that directory:
```
cd [BLUEPRINT_PATH]
git add bus/
git commit -m "janitor: archive bus entries for YYYY-MM"
git push origin [DEFAULT_BRANCH]
cd -
```

---

## Notes

- **Never delete LESSONS.md entries without user confirmation.**
- **Never delete bus entries before archiving them** — the archive is the record.
- Janitor does not touch application code or `.memory/` memory files directly (except LESSONS.md and NEEDS_REVIEW.md reviews in Steps 2-3). It manages blueprint-level files and surfaces stale items to the user.
- The blueprint has no ai-memory — all bus archiving and parity updates are committed directly to the blueprint's default branch.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
