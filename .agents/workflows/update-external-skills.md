---
name: update-external-skills
description: Refresh externally-maintained skill packs in the machine-level shared store (~/.agentskel/skills/) and re-link them into the current project. Run when sync-skeleton flags a pack as stale (>=30 days), or manually to pull the latest pack updates.
---

# Update External Skills

Updates the machine-level shared skill store at `~/.agentskel/skills/` and re-links
packs into the current project's `.agents/skills/`. One update refreshes all projects
on this machine that share the same pack.

## Authorization

Any developer may run this workflow. No PR required — external skills are not
committed to the project repository.

---

## Pre-Flight

1. Confirm `[SKELETON_PATH]` is available (read from `.memory/CONFIG.md` → `Skeleton Path`).
2. Read `[SKELETON_PATH]/core/external-skills.yml` — this is the manifest of all known packs.
3. Read `Platform` from `.memory/CONFIG.md` to determine which packs are relevant.
4. Read `External Platform Skills` and `Last External Skills Check` from `.memory/CONFIG.md`.

---

## Step 1 — Identify packs to update

From `core/external-skills.yml`, collect all entries where `platform_match` is a
case-insensitive substring of the project's `Platform` value.

If no packs match, report "No external skill packs registered for platform [Platform]"
and stop.

---

## Step 2 — Update shared store

For each matching pack:

```
SHARED_DIR=~/.agentskel/skills/[pack.id]
```

**If `SHARED_DIR` does not exist** — this is a first-time install on this machine:
1. Run `[pack.install_cmd]` (e.g. `android skills add --all --project=.`) from the project root.
   - If the CLI is not available, fall back to:
     ```bash
     git clone [pack.clone_url] ~/.agentskel/skills/[pack.id]-tmp
     mkdir -p ~/.agentskel/skills/[pack.id]
     cp -r ~/.agentskel/skills/[pack.id]-tmp/. ~/.agentskel/skills/[pack.id]/
     rm -rf ~/.agentskel/skills/[pack.id]-tmp
     ```
   - The install command puts files into `.agents/skills/` by default. After running,
     move/copy them to the shared store instead:
     ```bash
     # Move any newly-created skill dirs to shared store
     for dir in .agents/skills/*/; do
       skill=$(basename "$dir")
       # Skip first-party skills (present in [SKELETON_PATH]/core/skills/ or roles/dev/skills/)
       if [ ! -d "[SKELETON_PATH]/core/skills/$skill" ] && [ ! -d "[SKELETON_PATH]/roles/dev/skills/$skill" ]; then
         mv ".agents/skills/$skill" "~/.agentskel/skills/[pack.id]/$skill"
       fi
     done
     ```

**If `SHARED_DIR` exists** — refresh it:
- Preferred: re-run `[pack.install_cmd]` targeting the shared dir, if the CLI supports a target path.
- Fallback: `git -C ~/.agentskel/skills/[pack.id] pull` (if it's a git clone).
- If neither works: report to user with manual refresh instructions from `docs/PLATFORM-SKILLS.md`.

---

## Step 3 — Verify shared store

Scan `~/.agentskel/skills/[pack.id]/*/SKILL.md` for `metadata.author: [pack.author_tag]`.

- If one or more found → install confirmed. Proceed.
- If none found → report failure. Do not update CONFIG or create symlinks. Stop.

---

## Step 4 — Create / repair symlinks

For each skill directory under `~/.agentskel/skills/[pack.id]/`:

```bash
ln -sfn ~/.agentskel/skills/[pack.id]/[skill-dir] .agents/skills/[skill-dir]
```

After linking, append any new skill dir names to `.agents/skills/.gitignore`
(create the file if it doesn't exist). Avoid duplicates.

Example `.agents/skills/.gitignore` after Android install:
```
# External skill symlinks — machine-local, managed by install-agent.sh / update-external-skills
r8-analyzer
camera-migration
jetpack-compose-adaptive
jetpack-compose-theming
jetpack-compose-migration
agp-9-upgrade
testing-setup
navigation
identity
performance
system
play
profilers
xr
```

Commit `.agents/skills/.gitignore` if it changed:
```bash
git add .agents/skills/.gitignore
git commit -m "chore: update external skill gitignore entries ([pack.id])"
```

---

## Step 5 — Regenerate tool stubs and catalog

Re-run the stub and catalog regeneration so newly-added or renamed skills are
discoverable:

- `.claude/skills/` stubs (if `claude` in Supported Tools) — same logic as
  `setup-skeleton` Step 5b.
- `AGENTS.md` catalog — same logic as `setup-skeleton` Step 5d.

Commit if changed:
```bash
git add .claude/skills/ AGENTS.md
git commit -m "chore: regenerate skill stubs after external skills update"
```

---

## Step 6 — Update CONFIG

In `.memory/CONFIG.md`:
- Set `External Platform Skills` to `installed`
- Set `Last External Skills Check` to now (ISO 8601 UTC)

```bash
git -C .memory add CONFIG.md
git -C .memory commit -m "chore: update External Platform Skills check timestamp"
git -C .memory push origin ai-memory
```

---

## Step 7 — Report

Report to the user:
- Pack name and version/commit refreshed
- Skills added (new since last install) and removed (if any)
- Next suggested refresh: 30 days from now
- Any failures (broken CLI, network, etc.) with manual fallback instructions
