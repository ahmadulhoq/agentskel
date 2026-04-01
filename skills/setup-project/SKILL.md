---
name: setup-project
description: When setting up agentskel on a new project that does not yet have .memory/
  or .agents/. Use when the user says "set up agentskel", "install agentskel", or
  "add agent memory to this project".
---

# Set Up agentskel on This Project

**Purpose:** Guide the user through first-time agentskel setup by delegating to
the `setup-skeleton` workflow with the correct skeleton path.

---

## Step 1 — Resolve skeleton path

The agentskel skeleton is the source of all rules, skills, workflows, and templates.
Resolve the path using this chain (stop at the first match):

1. `$CLAUDE_PLUGIN_ROOT` — if set and the directory contains a `VERSION` file, use it
2. `../agentskel` — check if this sibling directory exists and contains `VERSION`
3. **Ask the user** — "Where is your agentskel clone? (e.g. `../agentskel`)"

---

## Step 2 — Delegate to setup-skeleton

Read and execute the full `setup-skeleton` workflow from the resolved skeleton path:

```
[SKELETON_PATH]/roles/dev/workflows/setup-skeleton.md
```

Pass the resolved skeleton path as the `Skeleton path on disk` input in Step 1
of setup-skeleton.

---

**Gate:** Do not proceed without a valid skeleton path containing a `VERSION` file.
