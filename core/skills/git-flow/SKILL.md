---
name: git-flow
description: Git branching, commit, and PR procedures. Use when creating branches,
  making commits, or opening pull requests. Enforces branch naming, commit message
  format, and PR rules.
---

# Git Flow Procedure

**All development follows the project's Git Workflow.**
Full spec: see `GIT_WORKFLOW.md` in the project's standards (`.agents/` or skeleton).

## Branch Creation

Before writing any code, create a branch:

- [ ] Switch to `[DEFAULT_BRANCH]` and pull latest:
  ```
  git checkout [DEFAULT_BRANCH] && git pull
  ```
- [ ] Create a new branch with the correct naming convention:
  - **Ticket given:** `BOARD-XXXX-kebab-description`
  - **Tech debt fix (no ticket):** `debt-id-kebab-description`
  ```
  git checkout -b <branch-name>
  ```
- [ ] Never push directly to `[DEFAULT_BRANCH]`.

## Commit Messages

- **Ticket work:** `[BOARD-XXXX] short description`
- **Tech debt:** `[DEBT-ID] short description`
- Commits must describe the change clearly.
- No empty commits. No WIP commits on shared branches.

## Opening a PR

When implementation is complete:

- [ ] Push the feature branch:
  ```
  git push -u origin <branch-name>
  ```
- [ ] Open a PR to `[DEFAULT_BRANCH]` with:
  - **Title:** `[BOARD-XXXX] short description` or `[DEBT-ID] short description`
  - **Body:** what changed, why, how to test, risk level
- [ ] **Do NOT merge** — a human reviewer must approve.
- [ ] Squash merge policy applies to feature/bug/chore branches.

## Rules

- Never merge your own PR.
- Minimum 1 approval + CI pass before merge.
- No changes during discussion — wait for explicit "go ahead" / "implement" / "yes".
- No commits without an implementation instruction from the user.
- When implementation is authorised, execute the full flow end-to-end
  (branch → implement → commit → PR) without pausing for additional approval.

---

**Gate:** Do not write any application code until a branch has been created.
Do not consider a task shipped until a PR is open.
