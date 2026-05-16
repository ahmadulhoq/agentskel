---
name: using-git-worktrees
license: MIT
description: When running long feature implementations, parallel branch work, or build/test scripts that must not interfere with the user's active working directory. Creates isolated execution environments via git worktrees in sibling directories.
---

# Using Git Worktrees Skill

**Purpose:** Keep the active repo clean. Work happens in a sibling directory — no nested git repos, no IDE re-indexing loops.

## When to Use
| Situation | Use worktree? |
|-----------|--------------|
| Long feature run (> ~30 min) | Yes |
| Parallel branch comparison | Yes |
| Running full build/test suite against a branch | Yes |
| Quick hotfix or single-file change | No — use normal branch |

## Setup
1. Confirm the feature branch exists (created by `git-flow` before any code):
   ```bash
   BRANCH=<branch-name>
   REPO=$(basename $(git rev-parse --show-toplevel))
   WORKTREE_PATH="../${REPO}-${BRANCH}"
   ```
2. Create the worktree:
   ```bash
   git worktree add "$WORKTREE_PATH" "$BRANCH"
   ```
3. Enter the worktree before running any build or test commands:
   ```bash
   cd "$WORKTREE_PATH"
   ```
4. All implementation, build, and test commands execute inside `$WORKTREE_PATH`.
   The main repo directory is effectively read-only during this session.

## Rules
- **Sibling directories only.** Never place a worktree inside the repo (e.g., `./worktrees/`). Nested paths cause IDE indexing loops and nested-git errors.
- One worktree per branch. Do not create multiple worktrees for the same branch.
- Do not edit files in the main repo directory while a worktree session is active.

## Cleanup (after PR is merged)
5. Return to main repo directory, then:
   ```bash
   git worktree remove "$WORKTREE_PATH"
   git branch -d "$BRANCH"   # only after merge is confirmed
   ```

---

**Gate:** Do not run build or test scripts in the main repo directory when a worktree
exists for the active branch.
