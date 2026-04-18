---
name: sync-workspace-dispatcher
description: When workspace dispatcher templates have changed in a newer skeleton
  version. Regenerates dispatcher files at the workspace root while preserving the
  workspace name, platforms list, and blueprint path from config.
---

# Sync Workspace Dispatcher

**Purpose:** Update workspace-level dispatcher files when skeleton templates change.
This is separate from per-subdir `sync-skeleton` — each platform subdir syncs
independently.

---

## Step 1 — Pre-flight

1. Confirm `.agentskel-workspace.yml` exists at CWD.
2. Read workspace config: note `workspace_name`, `skeleton_version`, `platforms`.
3. Read skeleton VERSION from `[SKELETON_PATH]/VERSION`.
4. Compare — if workspace `skeleton_version` is equal or newer than skeleton
   VERSION, report "Already up to date" and exit.

---

## Step 2 — Show changes

Read `[SKELETON_PATH]/CHANGELOG.md` entries between workspace's recorded version
and current. Show the user which changes affect workspace dispatcher templates
(look for `core/workspace-templates/` references in CHANGELOG entries).

For each workspace-relevant change, ask: Apply / Adapt / Skip.

---

## Step 3 — Regenerate dispatcher files

For each tool in the workspace's existing dispatcher files (check which files
exist at root), regenerate from the updated template:

- `AGENTS.md` — always regenerate (universal)
- `CLAUDE.md` — if exists
- `GEMINI.md` — if exists
- `.cursor/rules/agentskel.mdc` — if exists
- `.github/copilot-instructions.md` — if exists
- `.windsurf/rules/agentskel.md` — if exists
- `.claude/rules/routing.md` — if exists

For each: read the template from `[SKELETON_PATH]/core/workspace-templates/`,
replace `[WORKSPACE_NAME]` and `[PLATFORMS_LIST]` (reuse config values), write.

---

## Step 4 — Update workspace config

Update `.agentskel-workspace.yml`:
- `skeleton_version` → current VERSION

---

## Step 5 — Commit (if workspace root is a git repo)

```
git add -A
git commit -m "[chore] sync workspace dispatcher to skeleton v[VERSION]"
```

If workspace root is not a git repo, notify user that dispatcher files were
updated and need to be persisted however they normally manage workspace files.

---

## Step 6 — Reminder

Per-subdir syncs are independent. Remind the user:
- Each platform subdir has its own `.memory/CONFIG.md` `Skeleton Version`.
- To sync a platform subdir to the latest skeleton, `cd [subdir]` and run `sync-skeleton`.
