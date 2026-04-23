---
name: remove-workspace-platform
description: When removing a platform from the workspace dispatcher. Does NOT delete the subdir or its agentskel install — only unregisters it from workspace config and AGENTS.md.
---

# Remove Workspace Platform

**Purpose:** Unregister a platform from the workspace dispatcher. The platform
subdir and its agentskel install are left untouched — the user can delete them
manually if no longer needed.

---

## Step 1 — Input

| Input | Example |
|-------|---------|
| Platform name to remove | `ios` |

---

## Step 2 — Pre-flight

1. Confirm `.agentskel-workspace.yml` exists at CWD.
2. Confirm platform name exists in workspace config.
3. Confirm with user: "This removes [name] from the workspace dispatcher. The
   subdir and its .memory/, .agents/, and git repo are NOT deleted. Proceed?"

---

## Step 3 — Update workspace config

Remove the platform entry from `.agentskel-workspace.yml` `platforms` list.

---

## Step 4 — Regenerate AGENTS.md

Read `[SKELETON_PATH]/core/workspace-templates/AGENTS.md.template`. Replace
`[PLATFORMS_LIST]` with the updated (now-shorter) list. Write to workspace root
`AGENTS.md`.

---

## Step 5 — Commit (if workspace root is a git repo)

```
git add .agentskel-workspace.yml AGENTS.md
git commit -m "[chore] remove [platform name] from workspace platforms"
```

If workspace root is not a git repo, skip and notify user.

---

## Step 6 — Report

- Platform `[name]` removed from workspace dispatcher.
- Subdir `[path]` still exists with its agentskel install intact.
- Delete the subdir manually if no longer needed.
