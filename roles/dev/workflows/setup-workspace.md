---
name: setup-workspace
description: When setting up agentskel as a workspace dispatcher — multiple independent
  projects under one parent folder, each with its own git repo. Run once at the workspace
  root to create routing dispatcher files. Does NOT install agentskel in subdirs.
---

# Setup Workspace Dispatcher

**Purpose:** Install agentskel at the workspace root as a routing dispatcher.
Each subdirectory keeps its own independent agentskel installation.

**Scope:** Creates dispatcher files only at the workspace root. Does not create
`.memory/`, `.agents/`, or enforcement hooks at the root. User runs
`setup-skeleton` inside each platform subdir separately.

---

## Step 1 — Gather required information

| Input | Example |
|-------|---------|
| Workspace name | `my-org-workspace` |
| Supported tools | Comma-separated: `claude`, `antigravity`, `cursor`, `copilot`, `windsurf`, `codex` |
| Initial platforms (optional) | `backend,flutter,ios` — subdir names with existing git repos |
| Blueprint path (optional) | `./blueprint` or external path — informational only |
| Skeleton path | Auto-resolve: `$CLAUDE_PLUGIN_ROOT` → `../agentskel` → ask |

Confirm all inputs with the user.

---

## Step 2 — Pre-flight checks

1. Confirm CWD is the intended workspace root.
2. Confirm no existing `.agents/`, `.memory/`, or `.agentskel-workspace.yml` at CWD
   (workspace dispatcher must be fresh — if existing install found, stop and report).
3. Confirm each named platform subdir exists and is a git repo (run
   `git -C [subdir] rev-parse --git-dir`).
4. Confirm skeleton accessible.

---

## Step 3 — Create workspace config

Create `.agentskel-workspace.yml` at workspace root from
`[SKELETON_PATH]/core/workspace-templates/workspace-config.yml.template`.

Replace:
- `[WORKSPACE_NAME]` → workspace name
- `[SKELETON_VERSION]` → current skeleton VERSION

Populate `platforms` list with any initial platforms (name, path, `setup_complete: false`
since subdir setup hasn't run yet).

Set `blueprint_path` if provided.

---

## Step 4 — Create workspace AGENTS.md

Read `[SKELETON_PATH]/core/workspace-templates/AGENTS.md.template`.

Replace:
- `[WORKSPACE_NAME]` → workspace name
- `[PLATFORMS_LIST]` → generate a markdown list from the platforms in config:
  ```
  - backend/ — [platform name] (read backend/AGENTS.md)
  - flutter/ — [platform name] (read flutter/AGENTS.md)
  ```
  If no initial platforms: `- _(No platforms yet. Run `add-workspace-platform` to add.)_`

Write to `AGENTS.md` at workspace root.

---

## Step 5 — Create tool-specific dispatchers

Only create configs for tools in Supported Tools.

**Claude Code** (if `claude` in Supported Tools):
- Copy `[SKELETON_PATH]/core/workspace-templates/CLAUDE.md.template` → `CLAUDE.md`, replace `[WORKSPACE_NAME]`.
- Copy `[SKELETON_PATH]/core/workspace-templates/claude-rules/routing.md` → `.claude/rules/routing.md`.
  Create `.claude/rules/` directory first.

**Antigravity** (if `antigravity` in Supported Tools):
- Copy `[SKELETON_PATH]/core/workspace-templates/GEMINI.md.template` → `GEMINI.md`, replace `[WORKSPACE_NAME]`.

**Cursor** (if `cursor` in Supported Tools):
- Create `.cursor/rules/` directory.
- Copy `[SKELETON_PATH]/core/workspace-templates/cursor-rule.mdc.template` → `.cursor/rules/agentskel.mdc`, replace `[WORKSPACE_NAME]`.

**Copilot** (if `copilot` in Supported Tools):
- Create `.github/` directory if needed.
- Copy `[SKELETON_PATH]/core/workspace-templates/copilot-instructions.md.template` → `.github/copilot-instructions.md`, replace `[WORKSPACE_NAME]`.

**Windsurf** (if `windsurf` in Supported Tools):
- Create `.windsurf/rules/` directory.
- Copy `[SKELETON_PATH]/core/workspace-templates/windsurf-rule.md.template` → `.windsurf/rules/agentskel.md`, replace `[WORKSPACE_NAME]`.

---

## Step 6 — Report

Tell the user:
- Workspace dispatcher created at [CWD]
- Tools configured: [list from Supported Tools]
- Platforms registered: [list from initial platforms, or "none yet"]
- **Next steps:**
  1. For each platform subdir, run `setup-skeleton` inside that subdir. When asked
     "install mode", choose B (workspace platform).
  2. Or use `add-workspace-platform` workflow to add platforms one at a time.

---

## Notes

- Do NOT create `.memory/` at workspace root — dispatcher is stateless.
- Do NOT create `.agents/` at workspace root — routing only, no full rules.
- Do NOT install enforcement hooks at workspace root — no application code there.
- Each platform subdir is independent: own git repo, own memory, own rules, own hooks.
