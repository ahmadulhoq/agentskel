# Git Workflow
> Last updated: 2026-03-10

This document defines the Git workflow for all engineering repositories (iOS, Android, Backend). It applies to both human developers and AI agents.

---

## Base Branch

`development` is the standard base branch. Some repositories use `main` or `master` instead.

**The actual base branch for any given repo is stored in `.memory/CONFIG.md` (Operational Config → Default Branch).** Always read that value — never assume `development`. Direct pushes to the base branch are not allowed — all changes must go through a pull request.

---

## Branch Types & Naming

### Feature / Bug / Chore

Branches are created directly from tickets. Use the ticket ID followed by a short kebab-case description:

```
PE-3281-feature-ad-units
PE-4102-fix-screen-toggle
PE-5500-remove-legacy-activities
```

Rules:
- Always lowercase
- Hyphens as separators (not underscores)
- No type prefix (no `feature/`, `bug/`, `chore/`) — the ticket carries that context
- Short and descriptive

### Release

```
release/9.8.0
release/9.8.1
```

### Hotfix

Hotfix branches are cut from the **active release branch**, not from `development`:

```
PE-4210-fix-notification-crash
```

Same naming convention as feature branches — a ticket must exist.

### AI Agent — Tech Debt

When the agent fixes items from `TECH_DEBT.md` (no ticket), branch naming uses the debt registry ID:

```
bug-009-screen-toggle
ap-033-settings-god-class
ty-008-viewmodel-rename
```

---

## Commit Messages

All commits must be prefixed with the ticket ID in brackets:

```
[PE-3281] add ad unit configuration
[PE-4102] fix screen-on toggle updating wrong LiveData
```

For agent tech debt commits:

```
[BUG-009] fix screen-on toggle updating wrong LiveData
[AP-033] begin decomposing settings god class
```

---

## Pull Requests

- **All merges to `development` require a PR**
- Minimum **1 approving review** before merge
- **CI must pass** (lint, tests, build) before merge
- Use **squash merge** for all feature/bug/chore branches — one clean commit per ticket in `development` history
- PR title should match the commit message format: `[PE-XXXX] short description`

---

## Release Flow

```
development ──────────────────────────────────────→ (ongoing)
     │
     └──→ release/9.8.0
               │
               ├── [build & ship from release branch]
               │
               ├── [release fixes via PRs → release branch]
               │
               └──→ merge commit back to development
                         │
                         └── git tag v9.8.0
```

Steps:
1. Branch `release/x.y.z` from `development`
2. Build and ship from the release branch
3. Any release issues are fixed via PRs targeting the release branch
4. Once confirmed stable, merge the release branch back to `development` (merge commit, not squash)
5. Tag the resulting commit on `development`: `git tag v9.8.0`

---

## Hotfix Flow

### While the release branch is still open

Cut the hotfix branch from the active release branch:

```
release/9.8.0 → PE-XXXX-fix-name → PR → release/9.8.0
```

The fix travels to `development` when the release branch is merged back.

### After the release branch has been merged back

Cut a new release branch from the tagged commit on `development`:

```
git checkout v9.8.0
git checkout -b release/9.8.1
```

Fix, ship, merge back to `development`, tag `v9.8.1`.

---

## Multi-Developer Feature Branches

When a feature is split across two or more developers, personal sub-branches are cut from the feature branch:

```
PE-3000-feature-name          ← main feature branch (owner: lead dev)
PE-3000-feature-name-alice    ← personal sub-branch
PE-3000-feature-name-bob      ← personal sub-branch
```

Sub-branches are merged into the main feature branch via PR only. The main feature branch merges into `development` when complete.

---

## AI Agent — Session Start Protocol

At the start of every session, before touching any files, the agent must establish its git context.

### Step 1 — Check current branch

```bash
git branch --show-current
```

### Step 2 — Determine correct action based on branch

| Current branch | Situation | Action |
|---------------|-----------|--------|
|  | Clean start | Normal — proceed with task; create a feature branch when implementation begins |
| A feature/debt branch | Previous task in progress | Read RESUME.md to understand state; ask user whether to continue or abandon the branch |
| A feature/debt branch | No prior task context in RESUME.md | Ask user: "I'm on branch [branch-name]. Should I continue this work or check out [DEFAULT_BRANCH] for a new task?" |
| A release/hotfix branch | Release in progress | Do not start unrelated work; ask user for context before proceeding |

### Step 3 — Check for uncommitted changes

```bash
git status
```

| Situation | Action |
|-----------|--------|
| Working tree clean | Proceed normally |
| Uncommitted changes present | Surface them to the user before starting any new task — do not stash or discard silently |
| Untracked files present | Surface them; only proceed if they are related to the current task |

**Never discard, stash, or overwrite uncommitted changes without explicit user instruction.**

---

## AI Agent Workflow

| Work type | Ticket source | Branch naming | Commit prefix |
|-----------|--------------|---------------|---------------|
| Feature development | PM creates ticket, engineer assigns to agent | `PE-XXXX-feature-name` | `[PE-XXXX]` |
| Tech debt fix | `TECH_DEBT.md` registry | `bug-009-description` | `[BUG-009]` |

The agent follows the same PR process as any developer: branch → implement → PR to `development` → squash merge after approval.

---

## Quick Reference

| Scenario | Base branch | Naming | Merge into | Strategy |
|----------|------------|--------|------------|----------|
| Feature / bug / chore | `development` | `PE-XXXX-description` | `development` | Squash |
| Release | `development` | `release/x.y.z` | `development` | Merge commit |
| Hotfix (release open) | `release/x.y.z` | `PE-XXXX-description` | `release/x.y.z` | Squash |
| Hotfix (after merge-back) | tagged commit | `release/x.y.z+1` | `development` | Merge commit |
| Agent tech debt | `development` | `debt-id-description` | `development` | Squash |
