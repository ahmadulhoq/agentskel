---
name: session-start
description: Session initialization procedure. Checks memory mount, reads all required
  memory files, validates skeleton version, checks dependency freshness, and surfaces
  alerts. Must be executed at the start of every session before any other work.
---

# Session Start Procedure

**Execute every step below in order. Do not skip steps. Do not start any user task
until this procedure is complete.**

## Step 1 — Check memory mount

- [ ] Check whether `.memory/` exists in the repo root.
- **Exists →** pull the latest memory from remote before reading anything:
  ```bash
  git -C .memory pull --ff-only origin ai-memory 2>/dev/null || true
  ```
  If the pull fails (e.g. network unavailable, diverged history), warn the user
  but proceed — stale memory is better than no memory. Then continue to Step 2.
- **Does NOT exist →** STOP. Do not start any task. Instead:
  1. Run `git branch -r | grep origin/ai-memory`
  2. **Found →** tell the user:
     > "This project has AI memory but it's not mounted. Run `./scripts/install-agent.sh`
     > (or `git worktree add .memory ai-memory`) to load it, then restart this session."
  3. **Not found →** tell the user:
     > "This project has no AI memory. A tech lead needs to run the `setup-skeleton`
     > workflow first. See the agentskel README for setup instructions."
  4. **End session.** Do not attempt any work without memory files.

## Step 2 — Read memory files

Read all of the following files. Do not skip any:

- [ ] `.memory/CONFIG.md` — repo identity, operational config, check dates
- [ ] `.memory/RULES.md` — operating rules
- [ ] `.memory/MAP.md` — module and architecture map
- [ ] `.memory/SYMBOLS.md` — public classes and functions index
- [ ] `.memory/RESUME.md` — session state and persistent context
- [ ] `.memory/LESSONS.md` — past mistakes to avoid
- [ ] `.memory/SACRED.md` — behaviors that must never be changed
- [ ] `.memory/VERSIONS.md` — toolchain and dependency versions
- [ ] `.memory/DEPENDENCY_ALERTS.md` — open major/security alerts
- [ ] `.memory/NEEDS_REVIEW.md` — ambiguous findings awaiting human classification

## Step 3 — Surface alerts

- [ ] If `DEPENDENCY_ALERTS.md` has any OPEN entries, surface them to the user
      before starting any work.
- [ ] If `NEEDS_REVIEW.md` has any entries, surface them to the user.
      These are ambiguous findings awaiting human classification (SACRED or TECH_DEBT).

## Step 4 — Check skeleton version

- [ ] Read `VERSION` from the skeleton repo (resolve location via
      `Skeleton Path` in CONFIG.md → `../agentskel` → GitHub fetch fallback).
- [ ] Compare with `Skeleton Version` in `.memory/CONFIG.md`.
- [ ] If they differ → run `sync-skeleton` before any other task
      (unless the user explicitly says to skip the sync this session).

## Step 5 — Check freshness dates (from `.memory/CONFIG.md`)

- [ ] `Last Skeleton Check` — if >30 days ago or absent, run `check-skeleton`.
- [ ] `Last Dependency Check` — if >14 days ago or absent, run `check-dependencies`.
- [ ] `Last Conventions Check` — if >90 days ago or absent, remind the user
      and suggest running `update-conventions`. Do not auto-run it.
- [ ] `Last Blueprint Sync` — if `Blueprint Path` is set and `Last Blueprint Sync`
      is >7 days ago or absent, warn the user:
      > "Blueprint hasn't been synced in over 7 days. Other project agents may have
      > posted Knowledge Bus entries or updated domain specs since then."
      This is a warning only — do not block. Step 6 will pull the latest.

## Step 6 — Check blueprint (if configured)

- [ ] Read `Blueprint Path` from `.memory/CONFIG.md`.
- **Not set →** skip this step.
- **Set →** confirm the path exists on disk. If not, warn the user and continue.

### 6a — Detect blueprint changes

- [ ] Pull latest blueprint changes:
      ```bash
      git -C [BLUEPRINT_PATH] pull --ff-only 2>/dev/null || true
      ```
- [ ] Read `Last Blueprint Sync` from `.memory/CONFIG.md`.
- [ ] If set, check for new commits since that date:
      ```bash
      git -C [BLUEPRINT_PATH] log --after="[LAST_BLUEPRINT_SYNC]" --oneline
      ```
- [ ] If new commits exist, surface a summary to the user:
      > "Blueprint has been updated since your last session. N new commits — review the changes below before starting work."
      Show the commit list and any changed spec files (`specs/`, `parity/`).
- [ ] Update `Last Blueprint Sync` in `.memory/CONFIG.md` to today's date.

### 6b — Check blueprint skeleton version

- [ ] Read `[BLUEPRINT_PATH]/CONFIG.md` — note `Skeleton Version`.
- [ ] Compare with the current skeleton version (already resolved in Step 4).
- [ ] If the blueprint's skeleton version is behind:
      > "Blueprint's skeleton is behind (v[BLUEPRINT_SKEL_VERSION] vs v[CURRENT_SKEL_VERSION]).
      > Someone needs to run `sync-skeleton` from the blueprint repo to update it."
      This is informational — do not block the session. The project agent cannot
      sync the blueprint's skeleton; that must be done from the blueprint repo directly.

### 6c — Check Knowledge Bus

- [ ] List files in `[BLUEPRINT_PATH]/bus/` (excluding `BUS_ENTRY_TEMPLATE.md`,
      `archive/`, and `.gitkeep`).
- [ ] For each bus entry, read the file and check:
  1. **Target Platforms** — does it list this project's platform?
  2. **Action Required** — are there unchecked action items for this platform?
- [ ] If any bus entries have unchecked actions for this platform, surface them
      individually with their Change Summary and Action Required sections:
      > "N unprocessed Knowledge Bus entries targeting [PLATFORM]. These require
      > action before or during this session."
      List each entry's filename, origin agent, impact level, and the specific
      unchecked action item for this platform.
- [ ] If there are also bus entries targeting this platform where all actions are
      already checked, note them as informational only (no action needed).
- [ ] If any bus entries (for any platform) are older than 30 days, remind the
      user to run the `janitor` workflow to archive them.

## Step 7 — Check git state

- [ ] Run `git branch --show-current` and `git status`.
- [ ] If on a non-default branch → read RESUME.md and ask the user whether to
      continue in-progress work or return to `[DEFAULT_BRANCH]` for a new task.
- [ ] If uncommitted changes exist → surface them to the user before starting
      any new task. Never stash, discard, or overwrite without explicit instruction.

## Step 8 — Confirm ready

- [ ] Tell the user: session is ready. Summarise any alerts, version mismatches,
      stale checks, or pending bus entries found. Ask what they'd like to work on.

---

**Gate:** Do not begin any user task until all steps above are checked off.
