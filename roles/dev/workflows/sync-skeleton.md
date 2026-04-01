---
name: sync-skeleton
description: When skeleton version in CONFIG.md is behind the current agentskel VERSION.
  Run by tech lead to apply upstream skeleton improvements to a project. Changes go
  through a PR — never directly to the default branch.
---

# Sync Skeleton

## Authorization

This workflow may only be run by the **project tech lead** or **project owner**.
If you are not sure whether the current user is authorized, ask before proceeding.

---

## When to Run

- At session start, if the `Skeleton Version` in `.memory/CONFIG.md` differs
  from the current skeleton version — surface the gap to the user and
  offer to run this workflow
- When a tech lead or project owner explicitly requests a skeleton sync

---

## Pre-Flight Checks

1. Confirm the current user is the project tech lead or project owner.
2. Confirm `git status` is clean — no uncommitted changes on the default branch.
3. Resolve the skeleton location — follow this order:
   - Check `.memory/CONFIG.md` for a `Skeleton Path` field. If set and the path exists on disk — use it as `[SKELETON_PATH]`.
   - If not set, check `$CLAUDE_PLUGIN_ROOT` — if set and contains a `VERSION` file, use it.
   - If not set, probe common locations in order: `../agentskel`
   - If a local path is found — use it as `[SKELETON_PATH]`. If it wasn't stored in `CONFIG.md`, offer to save it now.
   - If **no local path is found** — ask the user:
     > "No local skeleton (agentskel) clone found. How would you like to proceed?
     > **A)** Clone it locally (provide the clone URL)
     > **B)** Read from GitHub directly (requires internet; will not see any local changes that haven't been pushed)"
   - If the user chooses **A** — run the clone, then use the local path as `[SKELETON_PATH]`.
   - If the user chooses **B** — use the `gh api` commands in the [GitHub Fetch Reference](#github-fetch-reference) section below. Confirm `gh auth status` passes before continuing.
4. Read the current skeleton version from `[SKELETON_PATH]/VERSION`.
5. Read the project's recorded version from `.memory/CONFIG.md` (`Skeleton Version` field).
6. If `.memory/CONFIG.md` does not exist, the project is on a pre-v3.5 setup. Note this — a migration step is required (see Step 5b).
7. If versions match — no sync needed. Confirm to the user and stop.

---

## Step 0 — Self-Update

**Before processing any changes, update this workflow itself.**

The sync-skeleton workflow may have changed in the new skeleton version. If
the project's copy is outdated, it may reference wrong paths or miss migration steps.

1. Read the latest `sync-skeleton.md` from the skeleton:
   - Local: `[SKELETON_PATH]/roles/dev/workflows/sync-skeleton.md`
   - GitHub: `gh api repos/[ORG]/[SKELETON_REPO]/contents/roles/dev/workflows/sync-skeleton.md --jq '.content' | base64 -d`
2. Compare it to the project's `.agents/workflows/sync-skeleton.md`.
3. If they differ:
   - Copy the new version into `.agents/workflows/sync-skeleton.md`
   - **Re-read the updated workflow and continue from Step 1** using the new instructions.
   - This ensures migration steps, path references, and logic are current.
4. If they match — continue to Step 1.

> **Why this matters:** The sync workflow references skeleton paths to locate templates.
> If those paths changed (e.g. a structural reorganization), the old workflow would fail.
> Self-updating first prevents this chicken-and-egg problem.

---

## Step 1 — Identify Changes

1. Read `[SKELETON_PATH]/CHANGELOG.md`.
2. Extract all entries **after** the project's recorded version up to and including
   the current version (e.g. if project is on 1.2 and skeleton is at 1.5, extract
   entries for 1.3, 1.4, and 1.5).
3. Present the full list of changes to the user — one line per item, grouped by version.

---

## Step 2 — Classify Each Change

For each change listed, ask the user to decide:

| Option | Meaning |
|--------|---------|
| **Apply** | Adopt as-is — copy the updated template/rule/workflow into the project's `.agents/` or `.memory/` files |
| **Adapt** | Apply with platform-specific modifications — use the updated logic but replace generic references with project-specific commands/paths |
| **Skip** | Not applicable to this project — document as a known deviation so it is not flagged again |

Record the decisions. Do not apply any changes until all items are classified and the
user has confirmed the full list.

---

## Step 3 — Create the Sync Branch

```bash
git checkout [DEFAULT_BRANCH]
git pull origin [DEFAULT_BRANCH]
git checkout -b chore/sync-skeleton-v[CURRENT_VERSION]
```

All project file changes (`.agents/`, `CLAUDE.md`, `CODEOWNERS`, etc.) happen on
this branch. The `.memory/` (ai-memory) branch is handled separately in Step 5.

---

## Step 4 — Apply Changes to Project Files

Apply all **Apply** and **Adapt** decisions:

- Updated workflow templates: `.agents/workflows/`
- Updated rule templates: `.agents/rules/`
- Updated standard templates: `.agents/standards/` (trim platform sections as with setup)
- Updated skill templates: `.agents/skills/` (trim platform sections in `developer`, `code-reviewer`, `test-engineer` — same as standards)
- Updated `AGENTS.md` template: project root `AGENTS.md` (regenerate skill/workflow catalogs from frontmatter — same logic as setup-skeleton Step 5d)
- Updated `CLAUDE.md` template: project root `CLAUDE.md` (only if `claude` in Supported Tools)
- Updated `GEMINI.md` template: project root `GEMINI.md` (only if `antigravity` in Supported Tools)
- Updated native tool configs (only for tools listed in `Supported Tools` in `.memory/CONFIG.md`): `.cursor/rules/agentskel.mdc`, `.github/copilot-instructions.md`, `.windsurf/rules/agentskel.md`
- Updated `CODEOWNERS` pattern: `.github/CODEOWNERS`

Read individual template files from the appropriate `[SKELETON_PATH]` directory:
- Memory templates: `[SKELETON_PATH]/core/memory/[FILENAME]`
- Rules: `[SKELETON_PATH]/core/rules/[FILENAME]`
- Procedural skills: `[SKELETON_PATH]/core/skills/[SKILL_NAME]/SKILL.md`
- Domain skills: `[SKELETON_PATH]/roles/dev/skills/[SKILL_NAME]/SKILL.md`
- Workflows: `[SKELETON_PATH]/roles/dev/workflows/[FILENAME]`
- Standards: `[SKELETON_PATH]/roles/dev/standards/[FILENAME]`
- Entry point templates: `[SKELETON_PATH]/core/AGENTS.md.template`, `[SKELETON_PATH]/core/CLAUDE.md.template`, `[SKELETON_PATH]/core/GEMINI.md.template`
- Native tool config templates: `[SKELETON_PATH]/core/cursor-rule.mdc.template`, `[SKELETON_PATH]/core/copilot-instructions.md.template`, `[SKELETON_PATH]/core/windsurf-rule.md.template`

For each **Adapt** change, note the platform-specific modification made alongside the
standard template change.

For each **Skip**, do not modify the file — record only (Step 6 handles this).

---

## Step 5 — Update Agent Memory (ai-memory branch)

These changes go directly to the ai-memory branch — no PR required.

```bash
cd .memory
```

Apply any memory file template updates (e.g. new sections in `RULES.md`,
updated `VERSIONS.md` schema). Then:

1. Update `.memory/CONFIG.md` — Operational Config:
   - Set `Skeleton Version` to `[CURRENT_VERSION]`
   - Update `Last Skeleton Check` to today's date
   - Add any **Skip** entries to the Intentional Deviations section (add this section
     at the bottom of CONFIG.md if it doesn't exist yet)

2. Commit and push:
```bash
git add -A
git commit -m "sync to skeleton v[CURRENT_VERSION]"
git push origin ai-memory
cd ..
```

---

## Step 5c — Migration: v1.20 to v1.21 (AGENTS.md universal entry point)

Skip this step if the project is already on skeleton v1.21+.

If the project's recorded skeleton version is < 1.21, the following one-time
migration is required:

1. Generate `AGENTS.md` in the repo root using the setup-skeleton Step 5d logic:
   - Read `[SKELETON_PATH]/core/AGENTS.md.template`
   - Replace `[APP_NAME]` and `[PLATFORM]` tokens (read from `.memory/CONFIG.md`)
   - Generate `[SKILLS_CATALOG]` from `.agents/skills/*/SKILL.md` YAML frontmatter
   - Generate `[WORKFLOWS_CATALOG]` from `.agents/workflows/*.md` YAML frontmatter
2. Update `CLAUDE.md` from `[SKELETON_PATH]/core/CLAUDE.md.template` (now a thin
   wrapper referencing AGENTS.md). Replace `[APP_NAME]` and `[PLATFORM]`.
3. Update `GEMINI.md` from `[SKELETON_PATH]/core/GEMINI.md.template` (now a thin
   wrapper referencing AGENTS.md). Replace `[APP_NAME]` and `[PLATFORM]`.

Include `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` in the Step 6 commit.

---

## Step 5d — Migration: v1.21 to v1.22 (Supported Tools + native tool configs)

Skip this step if the project is already on skeleton v1.22+.

If the project's recorded skeleton version is < 1.22, the following one-time
migration is required:

1. Add the `Supported Tools` field to `.memory/CONFIG.md` Operational Config table.
   Populate it by detecting which tool configs already exist:
   - `claude` — if `CLAUDE.md` exists in repo root
   - `antigravity` — if `GEMINI.md` or `.agent` exists in repo root
   - `codex` — if the user confirms they use Codex CLI
   Ask the user if they want to add support for any additional tools: `cursor`, `copilot`, `windsurf`.

2. For each newly added tool, create the native config:
   - **Cursor** (if `cursor` added) — create `.cursor/rules/agentskel.mdc` from
     `[SKELETON_PATH]/core/cursor-rule.mdc.template`. Replace `[APP_NAME]`.
   - **Copilot** (if `copilot` added) — create `.github/copilot-instructions.md` from
     `[SKELETON_PATH]/core/copilot-instructions.md.template`. Replace `[APP_NAME]` and
     `[PLATFORM]`. If `.github/copilot-instructions.md` already exists (user-created),
     do not overwrite — notify the user and skip.
   - **Windsurf** (if `windsurf` added) — create `.windsurf/rules/agentskel.md` from
     `[SKELETON_PATH]/core/windsurf-rule.md.template`. Replace `[APP_NAME]`.

Include any new tool config files in the Step 6 commit.

---

## Step 5e — Migration: v1.25 to v1.26 (plugin-based skeleton resolution)

Skip this step if the project is already on skeleton v1.26+.

If the project's recorded skeleton version is < 1.26, the following one-time
migration is required:

1. In `.agents/skills/session-start/SKILL.md` Step 4, update the skeleton version
   resolution chain from:
   `Skeleton Path in CONFIG.md → ../agentskel → GitHub fetch fallback`
   to:
   `Skeleton Path in CONFIG.md → $CLAUDE_PLUGIN_ROOT → ../agentskel → GitHub fetch fallback`

2. In `.agents/workflows/setup-skeleton.md` Step 1, update the `Skeleton path on disk`
   input to include: "If `$CLAUDE_PLUGIN_ROOT` is set and contains a `VERSION` file, use it."

3. In `.agents/workflows/sync-skeleton.md` Pre-Flight step 3, add `$CLAUDE_PLUGIN_ROOT`
   check between CONFIG.md and `../agentskel` in the resolution chain.

4. In `.agents/workflows/check-skeleton.md` Step 1, add `$CLAUDE_PLUGIN_ROOT`
   check between CONFIG.md and `../agentskel` in the resolution chain.

Include these changes in the Step 6 commit.

---

## Step 5f — Migration: v1.26 to v1.27 (skill rename + task-completion extraction)

Skip this step if the project is already on skeleton v1.27+.

If the project's recorded skeleton version is < 1.27, the following one-time
migration is required:

1. Rename the `developer` skill (formerly `senior-developer`):
   ```bash
   mv .agents/skills/senior-developer .agents/skills/developer
   mv .claude/skills/senior-developer.md .claude/skills/developer.md
   ```
   Update the `name:` field in `.agents/skills/developer/SKILL.md` frontmatter
   from `senior-developer` to `developer`.
   Update the path in `.claude/skills/developer.md` to point to `.agents/skills/developer/SKILL.md`.

2. Update all references to `senior-developer` in:
   - `AGENTS.md` catalog table
   - `.agents/workflows/develop-feature.md`, `fix-tech-debt.md`, `implement-task.md`
   - Any project-specific files that reference the skill by name

3. Replace `task-completion` Steps 5-5d with the new Step 5 that references
   `skeleton-contribution-checklist.md`. Copy the new checklist file from
   `[SKELETON_PATH]/core/skills/task-completion/skeleton-contribution-checklist.md`
   to `.agents/skills/task-completion/`.

Include these changes in the Step 6 commit.

---

## Step 5x — Adding New Migration Steps

When a breaking skeleton version requires project-level migration, add a new
migration step here following this pattern:

```
## Step 5[letter] — Migration: v[OLD] to v[NEW] ([short description])

Skip this step if the project is already on skeleton v[NEW]+.

If the project's recorded skeleton version is < [NEW], the following one-time
migration is required:

[numbered steps with exact commands and file changes]

Include these changes in the Step 5 memory commit and the Step 6 project files commit.
```

**Important:** Breaking changes to the skeleton MUST include a corresponding migration
step here. This is enforced by the task-completion checklist. See the CHANGELOG entry
for details on what changed and why migration is needed.

---

## Step 6 — Commit Project Files

Only include tool-specific files for tools listed in `Supported Tools`:

```bash
git add .agents/ AGENTS.md .github/CODEOWNERS .gitignore scripts/install-agent.sh
# Add only tool-specific files that exist (based on Supported Tools):
# claude: .claude/ CLAUDE.md .claudeignore
# antigravity: .agent GEMINI.md
# cursor: .cursor/
# copilot: .github/copilot-instructions.md
# windsurf: .windsurf/
git commit -m "[chore] sync agent setup to skeleton v[CURRENT_VERSION]

Changes applied from skeleton CHANGELOG:
[paste each applied change as a bullet point]

Skipped (not applicable):
[paste each skipped change with reason]

git push origin chore/sync-skeleton-v[CURRENT_VERSION]
```

---

## Step 7 — Open PR for Review

```bash
gh pr create \
  --title "Sync agent setup to skeleton v[CURRENT_VERSION]" \
  --body "$(cat <<'EOF'
## Skeleton sync: v[PROJECT_VERSION] -> v[CURRENT_VERSION]

### Applied
[bullet list of applied changes]

### Adapted (with project-specific modifications)
[bullet list of adapted changes and what was changed]

### Skipped (not applicable)
[bullet list of skipped changes and reason]

### Memory files
`.memory/CONFIG.md` Skeleton Version updated to v[CURRENT_VERSION] (already pushed to ai-memory).

**Review notes:** Check that adapted changes correctly reflect [PLATFORM]-specific commands and paths.
EOF
)" \
  --base [DEFAULT_BRANCH]
```

**Do NOT merge yourself.** The tech lead or project owner must review before merge.

---

## Step 8 — Session Reload

After sync is complete, re-execute the **`session-start`** skill (full procedure,
Steps 1–8) including a re-read of all `.agents/rules/` files. Rules, skills, and
workflows may have changed — the agent must internalize the updated versions before
continuing any other work.

---

## Classifying Changes: Quick Reference

| Change type | Decision |
|-------------|----------|
| Workflow logic, new rule, policy update | Apply |
| Generic tool reference (e.g. "run static analysis") | Adapt — replace with project-specific command |
| Rule for a platform or feature this repo doesn't use | Skip |
| Change already present in this repo (implemented ahead of skeleton) | Skip — note "already applied" |
| New memory file added to templates (e.g. `CONFIG.md`) | Apply — create the file in `.memory/` from the template, populating from existing memory where possible (see Step 5b) |

---

## GitHub Fetch Reference

Use these commands only when no local skeleton clone is available and the user chose option B in Pre-Flight step 3. Requires `gh` CLI installed and authenticated (`gh auth login`).

| File | Command |
|------|---------|
| `VERSION` | `gh api repos/[ORG]/[SKELETON_REPO]/contents/VERSION --jq '.content' \| base64 -d` |
| `CHANGELOG.md` | `gh api repos/[ORG]/[SKELETON_REPO]/contents/CHANGELOG.md --jq '.content' \| base64 -d` |
| `AGENTS.md.template` | `gh api repos/[ORG]/[SKELETON_REPO]/contents/core/AGENTS.md.template --jq '.content' \| base64 -d` |
| Memory template | `gh api repos/[ORG]/[SKELETON_REPO]/contents/core/memory/[FILENAME] --jq '.content' \| base64 -d` |
| Rule template | `gh api repos/[ORG]/[SKELETON_REPO]/contents/core/rules/[FILENAME] --jq '.content' \| base64 -d` |
| Workflow template | `gh api repos/[ORG]/[SKELETON_REPO]/contents/roles/dev/workflows/[FILENAME] --jq '.content' \| base64 -d` |
| `cursor-rule.mdc.template` | `gh api repos/[ORG]/[SKELETON_REPO]/contents/core/cursor-rule.mdc.template --jq '.content' \| base64 -d` |
| `copilot-instructions.md.template` | `gh api repos/[ORG]/[SKELETON_REPO]/contents/core/copilot-instructions.md.template --jq '.content' \| base64 -d` |
| `windsurf-rule.md.template` | `gh api repos/[ORG]/[SKELETON_REPO]/contents/core/windsurf-rule.md.template --jq '.content' \| base64 -d` |

---

## Notes

- Never commit sync changes directly to the default branch.
- The ai-memory branch (`CONFIG.md` update) does not need a PR — it is internal agent state.
- If a skip is later reversed (the feature is adopted), re-run this workflow or apply the change manually and remove it from Intentional Deviations.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
