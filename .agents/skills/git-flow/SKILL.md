---
name: git-flow
license: MIT
description: Git branching, commit, and PR procedures. Use when creating branches, making commits, or opening pull requests. Enforces branch naming, commit message format, and PR rules.
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

## Commit Granularity

- **Default:** one commit per logical change. A "logical change" is a single coherent unit that could stand on its own in `git log` — one bug fix, one new function, one refactor pass, one doc update. Not one giant end-of-workflow commit.
- **Honor user-specified commit granularity** for the duration of the workflow. If the user says "smaller commits", "atomic commits", "commit per file", "commit per logical unit", or equivalent, that granularity persists until the workflow ends — it is not a one-shot instruction for the next commit only. The workflow plan must include a `Commit granularity:` line stating the chosen strategy so it stays visible across steps.
- When user instruction is ambiguous ("smaller" — smaller than what?), ask once for clarification before the first commit. Don't guess.
- Defer to existing conventions in the project's GIT_WORKFLOW.md when there is a conflict, but only after surfacing the conflict to the user.

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
- [ ] **Present each PR URL on its own line** in the end-of-turn summary — one URL per line, format `PR #N: <url>` or just `<url>`. Never comma-separate or pack into a paragraph; the user needs to click each independently. When a turn opens multiple PRs (memory branch + main branch is the common case), list both:
  ```
  PR #42 (memory): https://github.com/.../pull/42
  PR #43 (main):   https://github.com/.../pull/43
  ```

## Rules

- Never merge your own PR.
- Minimum 1 approval + CI pass before merge.
- No changes during discussion — wait for explicit "go ahead" / "implement" / "yes".
- No commits without an implementation instruction from the user.
- When implementation is authorised, execute the full flow end-to-end
  (branch → implement → commit → PR) without pausing for additional approval.

## Fast Mode Bypass

Fast Execution Mode in `.memory/CONFIG.md` (or a one-shot `fast:` prefix on the user's request) skips the branch + PR ceremony for trivial work.

**When fast mode is active:**

- [ ] Surface a banner BEFORE any commit: `FAST MODE ACTIVE — committing directly to [DEFAULT_BRANCH] (no PR).` Surfacing is non-optional — ceremony-skipping must be visible.
- [ ] Verify the work is genuinely trivial. Fast mode is for typo fixes, version markers, lockfile bumps, dependency-version pins where review value is near zero. Anything touching logic, security, schema, or sacred behaviors → fast mode does NOT apply; fall back to the full flow and inform the user.
- [ ] Commit directly to `[DEFAULT_BRANCH]` (no feature branch).
- [ ] Push directly to origin (no PR opened).
- [ ] Task-completion checklist still runs in full: CHANGELOG, TIME_LOG, RESUME, memory commit. Validator still runs.
- [ ] Plan-first still applies — the user must still approve the change before any Edit/Write tool call.

**Toggling:**
- Persistent: edit `.memory/CONFIG.md` `Fast Execution Mode` field to `on` or `off`.
- One-shot: user prefixes a single request with `fast:` (e.g. `fast: bump python in versions.md`). The flag stays off; only that one task is fast.

**When to refuse fast mode:**
- The change touches `.agents/`, `core/`, `roles/`, or any skill/workflow/rule logic — these need review.
- The change touches `.memory/SACRED.md`-listed behavior.
- More than ~3 files modified.
- Any non-trivial logic change.

If the user invokes fast mode for one of these, surface a one-line objection: `Refusing fast mode — change touches X; switching to full flow.` and proceed with the normal branch + PR flow.

## Post-Merge Cleanup

When the user confirms a PR has been merged (says "merged", "done", or equivalent), the agent **must** execute cleanup BEFORE starting any next task. This is non-optional — leaving stale local/remote branches around accumulates and breaks the next branch creation.

- [ ] Confirm the branch name (check RESUME.md Next Task or current `git branch`
      output — never guess).
- [ ] Switch to default branch and pull:
  ```bash
  git checkout [DEFAULT_BRANCH]
  git pull origin [DEFAULT_BRANCH]
  ```
- [ ] Delete the local branch (safe delete — refuses if not fully merged):
  ```bash
  git branch -d <branch-name>
  ```
  If `-d` fails, report it to the user — do not force-delete with `-D` without
  explicit instruction.
- [ ] Prune stale remote-tracking refs:
  ```bash
  git remote prune origin
  ```
- [ ] Update RESUME.md: clear Next Task if it matches the merged branch, set
      Status to IDLE (or pull next P0 from BACKLOG.md if present).
- [ ] Verify the final state: `git branch -a` should show only the default branch and any other legitimate long-lived branches (e.g. `ai-memory`). No leftover feature branches.

**Gate:** do not begin the next task until the cleanup completes and `git branch -a` is clean.

## Git Worktrees (for long or parallel runs)

For long feature runs or parallel branch work, use an isolated worktree instead of
working directly in the main repo. See `using-git-worktrees` skill for full procedure.

**Quick reference:**
```bash
# Create (branch must already exist)
git worktree add "../$(basename $(git rev-parse --show-toplevel))-<branch-name>" <branch-name>

# Cleanup after merge
git worktree remove "../<repo>-<branch-name>"
git branch -d <branch-name>
```

- Use sibling directories only — never nest inside the repo.
- Run all build/test commands inside the worktree directory.

---

**Gate:** Do not write any application code until a branch has been created.
Do not consider a task shipped until a PR is open.
