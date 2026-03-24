---
name: setup-skeleton
description: One-time setup workflow. Wires up agentic development infrastructure on a new or existing project repo.
---

# Setup Skeleton Workflow

**Purpose:** Set up everything needed for agentic development on a project repo — memory files, rules, workflows, skills, CLAUDE.md, and CODEOWNERS.

**Scope:** This is a setup mission only. Do NOT modify any application code.

---

## Step 1 — Gather required information

Ask the user for the following. Do not proceed until all are confirmed.

| Input | Example |
|-------|---------|
| Platform | `android` / `ios` / `backend` |
| App name | `My App` |
| GitHub slug | `org/my-app-android` |
| Default branch | `development` (or `main`) |
| Lead engineer GitHub handle | `lead-dev` |
| Leads team name (without org) | `android-leads` |
| GitHub org | `my-org` |
| Skeleton path on disk | e.g. `../agentskel` |
| Blueprint path on disk (optional) | e.g. `../my-blueprint` (only for multi-project teams) |

Present the collected values to the user and ask for explicit confirmation before continuing.

---

## Step 2 — Pre-flight checks

1. Confirm the current working directory is the target project repo (not the skeleton).
2. Confirm `git status` is clean — no uncommitted changes.
3. Confirm the `ai-memory` branch does NOT already exist:
   ```bash
   git branch -a | grep ai-memory
   ```
   If it exists, stop and notify the user — this repo may already be set up.
4. Confirm `.memory/` directory does NOT already exist as a worktree.
5. Confirm the skeleton (agentskel) is accessible at the provided path.

---

## Step 3 — Create the ai-memory branch and worktree

The ai-memory branch is orphaned — it never touches the default branch and needs no review.

```bash
# Create orphaned ai-memory branch
git checkout --orphan ai-memory
git rm -rf .
git commit --allow-empty -m "init: ai-memory branch"
git push origin ai-memory

# Return to default branch
git checkout [DEFAULT_BRANCH]

# Mount ai-memory as a worktree at .memory/
git worktree add .memory ai-memory
```

---

## Step 3b — Create the setup branch

All project files (`.agents/`, `CLAUDE.md`, `CODEOWNERS`, `.gitignore`) go on a dedicated branch so the team can review them before they land on `[DEFAULT_BRANCH]`.

```bash
git checkout -b chore/setup-skeleton
```

All subsequent file creation (Steps 4-7) happens on this branch.

---

## Step 4 — Populate memory files

Read each template from `[SKELETON_PATH]/core/memory/` and create the corresponding file in `.memory/`, replacing all placeholder tokens:

| Token | Replace with |
|-------|-------------|
| `[PLATFORM]` | platform (e.g. `Android`) |
| `[APP_NAME]` | app name (e.g. `My App`) |
| `[REPO_SHORT_NAME]` | Short repo name (e.g. `my-app-android`) |
| `[GITHUB_SLUG]` | GitHub slug (e.g. `org/my-app-android`) |
| `[DEFAULT_BRANCH]` | default branch from Step 1 (e.g. `development`, `main`, `master`) |
| `[SKELETON_VERSION]` | current skeleton version from `[SKELETON_PATH]/VERSION` |

**Files to create in `.memory/`:**

- `CONFIG.md` — fill all placeholders; set `Status: pilot`
- `RULES.md` — fill all placeholders
- `MAP.md` — fill placeholders; leave module content blank (cartographer will populate it)
- `SYMBOLS.md` — fill placeholders; leave symbol content blank (cartographer will populate it)
- `RESUME.md` — set Status: `IDLE`, all other fields blank
- `VERSIONS.md` — fill `[DEFAULT_BRANCH]` and `[SKELETON_VERSION]`; leave dependency rows blank (sync-versions + check-dependencies will populate them)
- `CONVENTIONS.md` — fill placeholders; leave content blank (team to fill in)
- `SACRED.md` — fill placeholders; leave content blank (cartographer will populate it)
- `TECH_DEBT.md` — fill placeholders; leave rows blank
- `NEEDS_REVIEW.md` — fill placeholders; leave rows blank
- `LESSONS.md` — fill placeholders; leave rows blank
- `CHANGELOG.md` — fill placeholders; add one entry: `[today] — initial agentic setup via setup-skeleton workflow`
- `TIME_LOG.md` — fill placeholders; leave rows blank
- `DEPENDENCY_ALERTS.md` — create with empty Active Alerts section
- `DEPENDENCY_HISTORY.md` — create with header comment only; first entry will be added at first release

Commit all memory files to the ai-memory branch:
```bash
cd .memory
git add -A
git commit -m "setup-skeleton: initialise memory files"
git push origin ai-memory
cd ..
```

---

## Step 5 — Set up .agents/ structure

Create `.agents/rules/`, `.agents/workflows/`, `.agents/skills/`, and `.agents/standards/` directories.

**Rules** — copy from `[SKELETON_PATH]/core/rules/` and customise for platform:

- `.agents/rules/core-behavior.md` — from `[SKELETON_PATH]/core/rules/core-behavior.md`
- `.agents/rules/security-non-negotiables.md` — from `[SKELETON_PATH]/core/rules/security-non-negotiables.md`; add any platform-specific security rules (e.g. Android: never modify Keystore files, never trust intent extras without validation)
- `.agents/rules/repo-rules.md` — create with header only. This file is for project-specific rules that are unique to this repo (e.g. sacred patterns, domain constraints). It is never overwritten by setup or sync.

**Workflows** — copy from `[SKELETON_PATH]/roles/dev/workflows/`. Platform-specific notes:

| Workflow | Android | iOS | Backend |
|----------|---------|-----|---------|
| `cartographer.md` | yes | yes | yes |
| `develop-feature.md` | yes | yes | yes |
| `fix-tech-debt.md` | yes | yes | yes |
| `hotfix.md` | yes | yes | yes |
| `parity-check.md` | yes | yes | yes |
| `sync-skeleton.md` | yes | yes | yes |
| `check-skeleton.md` | yes | yes | yes |
| `sync-versions.md` | yes — fill in actual version file paths (`libs.versions.toml`, `Dependencies.kt`, etc.) | yes — fill in `Package.swift` / `Podfile` | yes — fill in relevant files |
| `check-dependencies.md` | yes | yes | yes |
| `update-conventions.md` | yes — trim reference table to Android/Kotlin sections | yes — trim reference table to iOS/Swift sections | yes — trim to matching backend stack section |
| `cut-release.md` | yes — fill in variant table and CI workflow names | yes — fill in CI workflow names | not applicable |
| `janitor.md` | yes | yes | yes |

For each workflow copied, fill in any `[TODO: platform-specific]` markers with the actual platform details.

**Standards** — copy from `[SKELETON_PATH]/roles/dev/standards/` into `.agents/standards/` and trim to the project's platform:

| Standard | Setup action |
|----------|-------------|
| `ARCHITECTURE.md` | Remove `<!-- PLATFORM: ... -->` sections for other platforms. Keep universal sections and the project's platform section(s). |
| `STYLE_GUIDE.md` | Remove `<!-- PLATFORM: ... -->` sections for other platforms. Keep universal sections and the project's language section(s). |
| `DEPENDENCY_MANAGEMENT.md` | Remove `<!-- PLATFORM: ... -->` sections for other platforms. Keep universal sections and the project's platform section(s). |
| `GIT_WORKFLOW.md` | Copy as-is. |
| `API_CONTRACT.md` | Copy as-is (stub — to be filled when backend is onboarded). |
| `ANDROID_ARCHITECTURE.md` | Copy only for Android projects. Adapt examples to match project domain. |
| `IOS_ARCHITECTURE.md` | Copy only for iOS projects. Adapt examples to match project domain. |

Platform sections in these files are marked with `<!-- PLATFORM: X -->` and `<!-- END PLATFORM: X -->` HTML comments. Remove the irrelevant platform blocks entirely (including the comment markers) so the installed copy reads cleanly for the project's stack.

**Skills** — copy from `[SKELETON_PATH]/core/skills/` (procedural) and `[SKELETON_PATH]/roles/dev/skills/` (domain):

Procedural (copy unchanged):
- `.agents/skills/session-start/SKILL.md` — from `core/skills/session-start/`
- `.agents/skills/task-completion/SKILL.md` — from `core/skills/task-completion/`
- `.agents/skills/git-flow/SKILL.md` — from `core/skills/git-flow/`

Domain (copy, then trim platform sections):
- `.agents/skills/senior-developer/SKILL.md` — from `roles/dev/skills/senior-developer/`
- `.agents/skills/test-engineer/SKILL.md` — from `roles/dev/skills/test-engineer/`
- `.agents/skills/code-reviewer/SKILL.md` — from `roles/dev/skills/code-reviewer/`
- `.agents/skills/task-planner/SKILL.md` — from `roles/dev/skills/task-planner/`
- `.agents/skills/domain-expert/SKILL.md` — from `roles/dev/skills/domain-expert/` (rename and fill in project domain)

Domain skills (`senior-developer`, `code-reviewer`, `test-engineer`) contain `<!-- PLATFORM: X -->` markers — the same format as standards. After copying, remove platform sections for other platforms. Keep the project's platform section(s) and any unmarked universal content.

---

## Step 5b — Generate .claude/skills/ stubs (Claude Code)

Claude Code auto-discovers skills from `.claude/skills/`. Generate a lightweight stub
for each skill and workflow in `.agents/` so Claude Code can see them without loading
the full file.

```bash
mkdir -p .claude/skills
```

For each file matching `.agents/skills/*/SKILL.md` and `.agents/workflows/*.md`:

1. Read the YAML frontmatter (`name` and `description` fields).
2. Create a stub at `.claude/skills/[name].md` with this format:

```markdown
---
description: [description from frontmatter]
---

Read and follow the full [skill|workflow] at `[relative path to the source file]`.
```

This generates stubs automatically — no separate template files to maintain.
When skills or workflows are added/removed, re-running setup or sync regenerates the stubs.

---

## Step 5c — Set up .agent/ symlink (Antigravity)

Antigravity expects `.agent/skills/`, `.agent/rules/`, `.agent/workflows/`. Create a
symlink so both tools share the same source of truth:

```bash
ln -s .agents .agent
```

---

## Step 5d — Add GEMINI.md (Antigravity entry point)

Create `GEMINI.md` in the repo root from `[SKELETON_PATH]/core/GEMINI.md.template`, replacing `[APP_NAME]` and `[PLATFORM]`.

---

## Step 6 — Add CLAUDE.md

Create `CLAUDE.md` in the repo root from `[SKELETON_PATH]/core/CLAUDE.md.template`, replacing `[APP_NAME]` and `[PLATFORM]`.

---

## Step 6b — Add .claudeignore

Create `.claudeignore` in the repo root from `[SKELETON_PATH]/core/.claudeignore`. Copy as-is — no placeholders to replace.

This file tells Claude which files to skip when reading the codebase. It prevents the agent from reading secret files, credentials, keystores, and local config that should never be surfaced.

---

## Step 7 — Set up CODEOWNERS

Create `.github/CODEOWNERS`. Use the pattern from the dependency management standard, filled in with the lead engineer handle and leads team:

**Android:**
```
# Code Owners
# Policy: see dependency management standard

# Gradle wrapper — controls Gradle version (toolchain)
/gradle/wrapper/gradle-wrapper.properties    @[LEAD_ENGINEER]

# Version catalog — controls all library and plugin versions (project dependencies)
/gradle/libs.versions.toml                   @[LEAD_ENGINEER] @[ORG]/[LEADS_TEAM]

# buildSrc constants — SDK levels and Java version are toolchain; Dependencies.kt is project dependencies
/buildSrc/src/main/java/BuildInfo.kt         @[LEAD_ENGINEER]
/buildSrc/src/main/java/Dependencies.kt      @[LEAD_ENGINEER] @[ORG]/[LEADS_TEAM]

# Root build file — controls AGP plugin version (toolchain)
/build.gradle                                @[LEAD_ENGINEER]

# CODEOWNERS itself
/.github/CODEOWNERS                          @[ORG]/[LEADS_TEAM]
```

**iOS:**
```
# Code Owners
# Policy: see dependency management standard

# Toolchain
/.xcode-version                              @[LEAD_ENGINEER]

# Project dependencies
/Package.swift                               @[LEAD_ENGINEER] @[ORG]/[LEADS_TEAM]
/Podfile                                     @[LEAD_ENGINEER] @[ORG]/[LEADS_TEAM]

# CODEOWNERS itself
/.github/CODEOWNERS                          @[ORG]/[LEADS_TEAM]
```

---

## Step 8 — Generate install-agent.sh

Create `scripts/install-agent.sh` in the project repo. This is the single command every
developer runs after cloning — it detects whether the project has ai-memory and acts
accordingly.

```bash
mkdir -p scripts
cat > scripts/install-agent.sh << 'SCRIPT'
#!/bin/bash
set -e

# install-agent.sh — Mount AI agent memory for this project.
# Run this once after cloning. Re-running is safe (idempotent).

if [ -d ".memory" ]; then
  echo "Done — .memory/ already exists. Nothing to do."
  exit 0
fi

echo "Fetching latest branches..."
git fetch origin

if git branch -r | grep -q origin/ai-memory; then
  echo "Found ai-memory branch. Mounting worktree..."
  git worktree add .memory ai-memory
  echo ""
  echo "Done — AI memory loaded at .memory/"
  echo "  Start Claude Code and begin working."
else
  echo ""
  echo "Error — This project has no AI memory yet."
  echo "  Ask your tech lead to run the setup-skeleton workflow first."
  exit 1
fi
SCRIPT
chmod +x scripts/install-agent.sh
```

Add `scripts/install-agent.sh` to the git staging in Step 9.

---

## Step 9 — Commit and open PR

Commit all project files to the setup branch and open a PR for review:

```bash
git add .gitignore .claudeignore .agents/ .claude/ .agent CLAUDE.md GEMINI.md .github/CODEOWNERS scripts/install-agent.sh
git commit -m "[chore] setup agentic development infrastructure

- .gitignore: exclude .memory/ worktree
- .claudeignore: prevent agent from reading secrets and credentials
- .agents/rules/: core-behavior, security-non-negotiables
- .agents/workflows/: cartographer, check-dependencies, check-skeleton,
  cut-release, develop-feature, fix-tech-debt, hotfix, janitor,
  parity-check, sync-skeleton, sync-versions, update-conventions
- .agents/standards/: architecture, style-guide, dependency-management,
  git-workflow, api-contract (trimmed to [PLATFORM])
- .agents/skills/: senior-developer, test-engineer, code-reviewer,
  task-planner, domain-expert, session-start, task-completion, git-flow
- .claude/skills/: Claude Code stub files for auto-discovery
- .agent: symlink to .agents/ for Antigravity compatibility
- CLAUDE.md: Claude Code entry point
- GEMINI.md: Antigravity entry point
- .github/CODEOWNERS: toolchain and dependency ownership
- scripts/install-agent.sh: developer onboarding script"
git push origin chore/setup-skeleton
```

Open a PR: `chore/setup-skeleton` -> `[DEFAULT_BRANCH]`

```bash
gh pr create \
  --title "Setup agentic development infrastructure" \
  --body "Sets up rules, workflows, standards, skills, CLAUDE.md, and CODEOWNERS for agentic development.

## What's included
- \`.agents/rules/\` — core behavior and security rules
- \`.agents/workflows/\` — cartographer, check-dependencies, check-skeleton, cut-release, develop-feature, fix-tech-debt, hotfix, janitor, parity-check, sync-skeleton, sync-versions, update-conventions
- \`.agents/standards/\` — architecture, style guide, dependency management, git workflow, API contracts (trimmed to [PLATFORM])
- \`.agents/skills/\` — senior-developer, test-engineer, code-reviewer, task-planner, domain-expert, session-start, task-completion, git-flow
- \`.claude/skills/\` — Claude Code stub files for auto-discovery
- \`.agent\` — symlink to .agents/ for Antigravity compatibility
- \`CLAUDE.md\` — Claude Code entry point
- \`GEMINI.md\` — Antigravity entry point
- \`.claudeignore\` — prevents agent from reading secrets, credentials, and key files
- \`.github/CODEOWNERS\` — toolchain and dependency ownership rules
- \`scripts/install-agent.sh\` — developer onboarding: run once after cloning to mount AI memory
- \`.gitignore\` — excludes \`.memory/\` worktree

## Review notes
- Workflows are customised for [PLATFORM] — check \`[TODO]\` markers are fully resolved
- CODEOWNERS references: lead engineer \`@[LEAD_ENGINEER]\`, leads team \`@[ORG]/[LEADS_TEAM]\`
- The \`ai-memory\` branch and \`.memory/\` worktree are already set up locally — this PR does not affect them

**Do not merge until the team has reviewed the rules and workflows.**" \
  --base [DEFAULT_BRANCH]
```

**Do NOT merge the PR yourself.** The team should review the installed rules and workflows before they land on `[DEFAULT_BRANCH]`.

---

## Step 10 — Report and next steps

Report to the user:
- ai-memory branch created and mounted at `.memory/`
- Memory files initialised (MAP.md, SYMBOLS.md, RULES.md, etc.)
- `.agents/` structure set up with rules, workflows, and skills (including procedural skills)
- `.claude/skills/` stubs created for Claude Code auto-discovery
- `.agent` symlink created for Antigravity compatibility
- CLAUDE.md added (Claude Code entry point)
- GEMINI.md added (Antigravity entry point)
- `.claudeignore` added (agent will not read secrets or credentials)
- CODEOWNERS configured
- `scripts/install-agent.sh` generated (developers run this after cloning)

**Next step:** Run the **`cartographer`** workflow to build the agent's memory of the codebase.

**For other developers:** After the setup PR is merged, any developer can start agentic
development by running `./scripts/install-agent.sh` after cloning the repo.

---

## Notes

- Never modify application code during this workflow.
- If any step fails, report the error clearly and stop. Do not attempt to work around it silently.
- If the repo already has a partial setup (some files exist), do not overwrite — report what exists and ask the user how to proceed.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
