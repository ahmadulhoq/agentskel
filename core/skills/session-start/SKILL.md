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
- **Exists →** proceed to Step 2.
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

## Step 3 — Surface alerts

- [ ] If `DEPENDENCY_ALERTS.md` has any OPEN entries, surface them to the user
      before starting any work.

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

## Step 6 — Check git state

- [ ] Run `git branch --show-current` and `git status`.
- [ ] If on a non-default branch → read RESUME.md and ask the user whether to
      continue in-progress work or return to `[DEFAULT_BRANCH]` for a new task.
- [ ] If uncommitted changes exist → surface them to the user before starting
      any new task. Never stash, discard, or overwrite without explicit instruction.

## Step 7 — Confirm ready

- [ ] Tell the user: session is ready. Summarise any alerts, version mismatches,
      or stale checks found. Ask what they'd like to work on.

---

**Gate:** Do not begin any user task until all steps above are checked off.
