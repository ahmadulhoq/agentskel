---
name: add-workspace-platform
description: When adding a new platform (subdir with its own git repo) to an existing
  workspace dispatcher. Runs setup-skeleton in the subdir and updates the workspace
  config and dispatcher AGENTS.md.
---

# Add Workspace Platform

**Purpose:** Register a new platform subdirectory with the workspace dispatcher and
run setup-skeleton inside it.

**Prerequisites:** Workspace dispatcher must already exist (`.agentskel-workspace.yml`
at CWD). If not, run `setup-workspace` first.

---

## Step 1 — Gather inputs

| Input | Example |
|-------|---------|
| Subdir path (relative to workspace root) | `./ios` |
| Platform name (identifier in dispatcher) | `ios` |
| Platform tech stack | `iOS` — for setup-skeleton input |
| Description | `Native iOS app` |

Ask the user for these. Also confirm: "This will run setup-skeleton inside
[subdir]. You'll be asked for the usual setup inputs (app name, GitHub slug,
lead engineer, etc.). Proceed?"

---

## Step 2 — Pre-flight checks

1. Confirm `.agentskel-workspace.yml` exists at CWD (workspace root).
2. Confirm `[subdir]` exists and is a git repo.
3. Confirm `[subdir]/.memory/` does NOT exist (platform not already installed).
4. Confirm the platform name is not already in workspace config.

---

## Step 3 — Run setup-skeleton in subdir

`cd [subdir]` and run the full `setup-skeleton` workflow there.

When setup-skeleton asks "install mode", the agent picks **B) Workspace platform**.
This tells setup-skeleton to:
- Proceed with normal install
- Skip the "install mode question" (already answered)
- At the end, update parent's `.agentskel-workspace.yml`

Wait for setup-skeleton to complete (including its PR creation).

---

## Step 4 — Update workspace config

`cd ..` back to workspace root. Update `.agentskel-workspace.yml`:
- Add platform entry: `name`, `path`, `setup_complete: true`

---

## Step 5 — Regenerate workspace AGENTS.md

Read `[SKELETON_PATH]/core/workspace-templates/AGENTS.md.template`. Replace
`[WORKSPACE_NAME]` and `[PLATFORMS_LIST]` (rebuild full platform list from updated
config). Write to `AGENTS.md` at workspace root.

---

## Step 6 — Commit workspace root changes

```
git add .agentskel-workspace.yml AGENTS.md
git commit -m "[chore] add [platform name] as workspace platform"
```

Note: this commit is at the workspace root, which may or may not be a git repo.
If workspace root is NOT a git repo, skip this step and tell the user to handle
the dispatcher files manually (they're typically committed into a workspace-level
dotfiles repo or kept local).

---

## Step 7 — Report

- Platform `[name]` registered in workspace
- setup-skeleton PR opened in `[subdir]` — review and merge
- Workspace dispatcher updated

---

## Notes

- Each platform remains independent — own git repo, own memory, own rules.
- Workspace root only tracks which platforms exist; it doesn't own their state.
- Removing a platform: use `remove-workspace-platform` (doesn't delete the subdir).
