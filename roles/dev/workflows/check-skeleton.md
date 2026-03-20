---
name: check-skeleton
description: Checks whether this project's skeleton version is current. Surfaces the version gap and offers to run sync-skeleton. Run at the start of any session where skeleton drift might have accumulated, or on a scheduled basis.
---

# Check Skeleton Workflow

**Trigger:** At session start if `Last Skeleton Check` in `.memory/CONFIG.md` is more than 30 days ago (or absent).
**Purpose:** Detect skeleton version drift and surface it to the user before work begins.

---

## Pre-Flight

1. Read `.memory/CONFIG.md` — note `Skeleton Version` and `Last Skeleton Check`.
2. If `Last Skeleton Check` is within 30 days **and** versions match — no action needed. Inform the user the skeleton is current and stop.

---

## Step 1 — Resolve Skeleton Location

Follow this order to determine `[SKELETON_PATH]`:
- Check `.memory/CONFIG.md` for a `Skeleton Path` field. If set and the path exists on disk — use it.
- If not set, probe common locations in order: `../agentskel`
- If a local path is found — use it. If it wasn't stored in `CONFIG.md`, offer to save it now.
- If **no local path is found** — ask the user:
  > "No local skeleton (agentskel) clone found. How would you like to proceed?
  > **A)** Clone it locally (provide the clone URL)
  > **B)** Read from GitHub directly (requires internet)"
  - If A — clone, then use the local path.
  - If B — use `gh api` commands to read VERSION and CHANGELOG.md from the skeleton repo.

---

## Step 2 — Read and Compare Versions

Record:
- `project_version` — from `.memory/CONFIG.md` `Skeleton Version` field
- `current_version` — from `[SKELETON_PATH]/agent-hq/VERSION`

If `project_version == current_version`:
1. Update `Last Skeleton Check` in `.memory/CONFIG.md` to today's date (Step 4).
2. Report: "Skeleton is current at v[current_version]. No sync needed."
3. Stop.

If `project_version != current_version`:
1. Read `[SKELETON_PATH]/agent-hq/CHANGELOG.md`.
2. Extract all entries from `project_version` up to `current_version`.
3. Count the entries and list version numbers.
4. Surface to the user:
   > "Skeleton has updates: v[project_version] -> v[current_version] ([N] versions behind).
   > Run `sync-skeleton` to review and apply the changes."
5. Proceed to Step 3.

---

## Step 3 — Offer to Run Sync

Present the CHANGELOG summary to the user (one line per version entry).

Ask:
> "Would you like to run `sync-skeleton` now to review and apply these changes?"

- If yes: run the `sync-skeleton` workflow (requires tech lead / project owner authorization).
- If no: note the gap and continue with the current session. The check will repeat the next session.

---

## Step 4 — Update Last Skeleton Check

In `.memory/CONFIG.md`, update `Last Skeleton Check` to today's date:
```
| Last Skeleton Check | YYYY-MM-DD |
```

Commit to the ai-memory branch:
```bash
cd .memory
git add CONFIG.md
git commit -m "check-skeleton: update check date [YYYY-MM-DD]"
git push origin ai-memory
cd ..
```

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
