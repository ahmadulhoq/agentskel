---
name: create-blueprint
description: Creates a new blueprint repo for shared team domain knowledge.
  Run once per organization/team to set up specs, parity tracking, and the knowledge bus.
---

# Create Blueprint Workflow

**Purpose:** Set up a new blueprint repository — the shared domain knowledge layer for multi-project teams. The blueprint holds business logic specs, cross-platform parity tracking, and the knowledge bus. It contains zero application code and zero agent memory.

**When to use:** When you have two or more projects that share business domain knowledge (e.g. Android + iOS + Backend for the same product) and you want agents to maintain domain parity across them.

**Scope:** This is a setup mission only. Do NOT modify any application code in downstream projects.

**Important:** The blueprint is a knowledge hub, not an agent workspace. Project-specific agents (e.g. the Muslim-Pro-Android agent) manage blueprint content by reading and writing to it via `Blueprint Path` in their own `.memory/CONFIG.md`. The blueprint itself has no ai-memory branch and no persistent agent state.

---

## Step 1 — Gather required information

Ask the user for the following. Do not proceed until all are confirmed.

| Input | Example |
|-------|---------|
| Organization / team name | `bitsmedia` |
| Blueprint repo name | `bitsmedia-blueprint` |
| GitHub slug | `bitsmedia/Bitsmedia-Blueprint` |
| Default branch | `main` |
| Target platforms | `Android, iOS, Backend` |
| Skeleton path on disk | e.g. `../agentskel` |
| Domain areas (initial) | e.g. `prayer-times, auth, qibla, hijri-calendar` |

Present the collected values to the user and ask for explicit confirmation before continuing.

---

## Step 2 — Pre-flight checks

1. Confirm the current working directory is the target blueprint repo (not a project or the skeleton).
2. Confirm `git status` is clean — no uncommitted changes.
3. Confirm the skeleton (agentskel) is accessible at the provided path.
4. Read `[SKELETON_PATH]/VERSION` to get the current skeleton version.

---

## Step 3 — Create the setup branch

All files go on a dedicated branch so the team can review before merging.

```bash
git checkout -b chore/create-blueprint
```

All subsequent file creation (Steps 4-8) happens on this branch.

---

## Step 4 — Create blueprint domain structure

These directories hold the team's shared domain knowledge. Create them with initial templates.

### 4a — Domain specs

```bash
mkdir -p specs
```

For each domain area from Step 1, create a spec stub:

```markdown
# [Domain Area] — Business Logic Spec

> Owner: [team]
> Last updated: [today]
> Platforms: [TARGET_PLATFORMS]

## Overview
[One-paragraph description of this domain area]

## Business Rules
[Document the business rules that all platforms must implement identically]

## Edge Cases
[Document known edge cases and how they should be handled]

## Data Contracts
[Document shared data structures, API payloads, or calculation inputs/outputs]

## Platform Notes
[Any platform-specific implementation notes]
```

### 4b — Parity matrix

```bash
mkdir -p parity
```

Create `parity/PARITY_MATRIX.md`:

```markdown
# Cross-Platform Parity Matrix

> Last updated: [today]
> Maintained by: project agents (via parity-check workflow)

| Business Logic | [Platform1] | [Platform2] | [Platform3] | Notes |
|---------------|-------------|-------------|-------------|-------|
```

Add one row per domain area from Step 1, all set to `—` (not yet tracked).

### 4c — Knowledge Bus

```bash
mkdir -p bus bus/archive
```

Create `bus/BUS_ENTRY_TEMPLATE.md`:

```markdown
# Knowledge Bus Entry

- **Timestamp:** YYYY-MM-DDTHH:MM:SSZ
- **Origin Agent:** [Platform] Agent
- **Impact Level:** LOW | MEDIUM | HIGH
- **Target Platforms:** [list]

## Change Summary
[What changed and why]

## Cross-Platform Impact
[What other platforms need to do]

## Action Required
- [ ] [Platform] agent: [specific action]
```

Create `bus/archive/.gitkeep` and `bus/.gitkeep`.

---

## Step 5 — Create CONFIG.md

Create a lightweight `CONFIG.md` at the repo root (NOT in `.memory/` — blueprints have no ai-memory):

```markdown
# Blueprint Config — [BLUEPRINT_NAME]

| Field | Value |
|-------|-------|
| Name | [BLUEPRINT_NAME] |
| GitHub | [GITHUB_SLUG] |
| Type | Blueprint |
| Platforms | [TARGET_PLATFORMS] |
| Default Branch | [DEFAULT_BRANCH] |
| Skeleton Version | [SKELETON_VERSION] |

## Domain Areas
[List each domain area from Step 1]

## Connected Projects
[List projects that reference this blueprint — filled in as projects are connected]
```

---

## Step 6 — Set up .agents/ structure

The blueprint includes `.agents/` as a safety net — if someone opens the repo directly in Claude Code, the agent has guardrails. But the primary workflow is that **project agents manage blueprint content remotely** via `[BLUEPRINT_PATH]`.

**Rules** — copy from `[SKELETON_PATH]/core/rules/`:

- `.agents/rules/core-behavior.md` — copy and trim for blueprint context:
  - Remove "Verify before done" (no tests/logs), "Self-improvement" (no `.memory/LESSONS.md`), "Respect sacred behaviors" (no `.memory/SACRED.md`)
  - Remove "Task Completion" section (no `task-completion` skill)
  - Remove "Memory Protocol" section (no `.memory/`, no `ai-memory`, no `session-start`)
  - Remove "Skeleton Contribution" section (blueprint agents don't push to agentskel)
  - Remove "Blueprint Contribution" section (this IS the blueprint)
  - Add a "Blueprint Identity" section explaining: stateless knowledge hub, no `.memory/`, read `CONFIG.md` at repo root
- `.agents/rules/security-non-negotiables.md` — copy as-is (harmless even if some rules don't apply)
- `.agents/rules/repo-rules.md` — create with blueprint-specific rules:

```markdown
---
activation: always
description: Rules specific to this blueprint repository.
---

# Repo-Specific Rules — [BLUEPRINT_NAME]

## Blueprint Scope
- This repo contains ONLY shared domain knowledge — no application code, no framework templates.
- Domain specs in `specs/` are the source of truth for business logic across all platforms.
- Changes to domain specs must include a Knowledge Bus entry if they affect existing implementations.

## Knowledge Bus
- Every spec change that affects running code requires a bus entry in `bus/`.
- Use the template at `bus/BUS_ENTRY_TEMPLATE.md`.
- Never edit existing bus entries — they are append-only.
- Project agents archive processed entries via the janitor workflow.

## Parity Matrix
- Keep `parity/PARITY_MATRIX.md` up to date when platform versions change.
- Version numbers in the matrix refer to spec versions, not app versions.

## No Agent Memory
- This repo has no ai-memory branch and no `.memory/` directory.
- Blueprint content is managed by project-specific agents via `Blueprint Path` in their own CONFIG.md.
- If you are working directly in this repo, use `CONFIG.md` at the repo root for identity.
```

**Workflows** — copy from `[SKELETON_PATH]/roles/dev/workflows/`:

| Workflow | Include? | Notes |
|----------|----------|-------|
| `develop-feature.md` | no | 100% app development workflow — references `.memory/`, tests, SYMBOLS.md |
| `parity-check.md` | no | Runs from project context, not blueprint |
| `janitor.md` | no | Runs from project context, not blueprint |
| `cartographer.md` | no | Blueprint has no application code to map |
| `sync-skeleton.md` | yes, trimmed | Keeps blueprint's .agents/ in sync with skeleton — replace `.memory/CONFIG.md` with root `CONFIG.md`, remove ai-memory commit steps, remove task completion checklist, add blueprint trimming note to Step 0, include Step 5x migration mechanism (adapted for blueprint — migrations go in the sync branch commit, not ai-memory) |
| `check-skeleton.md` | yes, trimmed | Detects skeleton drift — replace `.memory/CONFIG.md` with root `CONFIG.md`, remove ai-memory commit steps, remove task completion checklist |
| `fix-tech-debt.md` | no | Blueprint has no app code to fix |
| `hotfix.md` | no | Blueprint has no app releases |
| `cut-release.md` | no | Blueprint has no app releases |
| `sync-versions.md` | no | Blueprint has no app dependencies |
| `check-dependencies.md` | no | Blueprint has no app dependencies |
| `update-conventions.md` | no | Blueprint has no code conventions |

**Standards** — copy from `[SKELETON_PATH]/roles/dev/standards/`:

- `GIT_WORKFLOW.md` — create a simplified blueprint version: keep branch naming (with blueprint-appropriate types like `docs/`, `chore/`), commit messages, and PR rules. Remove release flow, hotfix flow, multi-developer branches, AI agent session protocol, tech debt branches, and all `.memory/` references.
- `STYLE_GUIDE.md` — copy; keep only Markdown/documentation sections (no platform code sections)
- Skip `ARCHITECTURE.md`, `DEPENDENCY_MANAGEMENT.md`, `API_CONTRACT.md`, `ANDROID_ARCHITECTURE.md`, `IOS_ARCHITECTURE.md` — these are for application projects, not blueprints.

**Skills** — copy from `[SKELETON_PATH]/core/skills/` and `[SKELETON_PATH]/roles/dev/skills/`:

Procedural (copy unchanged):
- `.agents/skills/git-flow/SKILL.md`

Blueprint-specific (create new — do NOT copy the project version):
- `.agents/skills/session-start/SKILL.md` — create a trimmed blueprint session-start:
  1. Read `CONFIG.md` (repo root) and all rules in `.agents/rules/`
  2. Check skeleton version (resolve `../agentskel` → GitHub fallback, compare with `Skeleton Version` in CONFIG.md, offer sync if mismatched)
  3. Check git state (current branch, uncommitted changes)
  4. Confirm ready
  No memory mount check, no dependency alerts, no blueprint check (this IS the blueprint), no freshness dates.

Domain (copy and trim):
- `.agents/skills/task-planner/SKILL.md` — replace `.memory/LESSONS.md` reference with generic wording, replace "Blueprint Check (if configured)" with "Domain Check" section pointing to local `specs/` and `parity/` paths

Skip (not applicable to blueprints):
- `senior-developer` — 100% about writing application code (SOLID, platform standards, performance)
- `session-start` (project version) — requires `.memory/`; use the blueprint-specific version above instead
- `task-completion` — requires `.memory/` for CHANGELOG, RESUME, TIME_LOG
- `test-engineer` — blueprint has no code to test
- `code-reviewer` — blueprint has no code to review
- `domain-expert` — domain knowledge lives in `specs/`, not agent skills

---

## Step 6b — Generate .claude/skills/ stubs

Same as setup-skeleton — generate a stub for each skill and workflow:

```bash
mkdir -p .claude/skills
```

For each file matching `.agents/skills/*/SKILL.md` and `.agents/workflows/*.md`:

1. Read the YAML frontmatter (`name` and `description` fields).
2. Create a stub at `.claude/skills/[name].md`:

```markdown
---
description: [description from frontmatter]
---

Read and follow the full [skill|workflow] at `[relative path to the source file]`.
```

---

## Step 6c — Set up .agent/ symlink and entry points

```bash
# Antigravity compatibility
ln -s .agents .agent
```

Create a simplified `CLAUDE.md` (no memory references since blueprint has no ai-memory):

```markdown
# [BLUEPRINT_NAME] — Claude Code Instructions

Before starting any task, execute the `session-start` skill.
Read `specs/` for domain knowledge.
Read `parity/PARITY_MATRIX.md` for cross-platform status.
Read `bus/` for pending Knowledge Bus entries.
```

Create `GEMINI.md` from `[SKELETON_PATH]/core/GEMINI.md.template`, simplified similarly.

Copy `.claudeignore` from `[SKELETON_PATH]/core/.claudeignore`.

---

## Step 7 — Create VERSION and CHANGELOG

Create `VERSION` in the repo root:

```
1.0
```

Create `CHANGELOG.md` in the repo root:

```markdown
# [BLUEPRINT_NAME] Changelog

## v1.0 — [TODAY]

Initial blueprint setup.

### Domain
- Created spec stubs for: [list domain areas]
- Parity matrix initialized for: [list platforms]
- Knowledge Bus structure with entry template

### Infrastructure
- .agents/ with rules, workflows, skills, standards from agentskel v[SKELETON_VERSION]
- Claude Code stubs and Antigravity compatibility
- CONFIG.md with blueprint identity
```

---

## Step 8 — Update .gitignore

Ensure `.gitignore` does NOT include `.memory/` (blueprints have no ai-memory).

Add standard ignores only:

```
.DS_Store
```

---

## Step 9 — Commit and open PR

```bash
git add .gitignore .claudeignore .agents/ .claude/ .agent CLAUDE.md GEMINI.md \
       VERSION CHANGELOG.md CONFIG.md specs/ parity/ bus/
git commit -m "[chore] create blueprint repository

- specs/: domain spec stubs for [DOMAIN_AREAS]
- parity/PARITY_MATRIX.md: cross-platform tracking for [PLATFORMS]
- bus/: knowledge bus with entry template
- CONFIG.md: blueprint identity
- VERSION: 1.0
- CHANGELOG.md: initial entry
- .agents/: rules, workflows, skills, standards from agentskel v[SKELETON_VERSION]
- .claude/skills/: Claude Code stubs
- CLAUDE.md, GEMINI.md: entry points"
git push origin chore/create-blueprint
```

Open a PR: `chore/create-blueprint` -> `[DEFAULT_BRANCH]`

```bash
gh pr create \
  --title "Create blueprint repository" \
  --body "Sets up the shared domain knowledge repository for [ORG_NAME].

## What's included

### Domain Knowledge
- \`specs/\` — business logic spec stubs for: [DOMAIN_AREAS]
- \`parity/PARITY_MATRIX.md\` — cross-platform feature tracking ([PLATFORMS])
- \`bus/\` — knowledge bus for cross-project notifications

### Infrastructure
- \`CONFIG.md\` — blueprint identity and connected projects
- \`.agents/\` — rules, workflows, skills, standards from agentskel v[SKELETON_VERSION]
- \`.claude/skills/\` — Claude Code auto-discovery stubs
- \`CLAUDE.md\`, \`GEMINI.md\` — entry points

### Design
- **No ai-memory branch.** The blueprint is a knowledge hub, not an agent workspace.
- Project-specific agents manage blueprint content via \`Blueprint Path\` in their own CONFIG.md.
- \`.agents/\` provides guardrails if someone opens the blueprint repo directly.

## Next steps
1. Review and merge this PR
2. Add \`Blueprint Path\` to each project's \`.memory/CONFIG.md\`
3. Fill in domain specs in \`specs/\` with actual business logic
4. Run \`parity-check\` workflow from a connected project to populate the parity matrix

**Do not merge until the team has reviewed the domain structure.**" \
  --base [DEFAULT_BRANCH]
```

---

## Step 10 — Report and next steps

Report to the user:
- Blueprint structure created: `specs/`, `parity/`, `bus/`
- Domain spec stubs created for each domain area
- Parity matrix initialized for target platforms
- Knowledge Bus ready with entry template
- `.agents/` set up with rules, workflows, skills, standards (safety net)
- CONFIG.md with blueprint identity
- VERSION set to 1.0; CHANGELOG has initial entry
- **No ai-memory** — project agents manage this blueprint remotely

**Next steps for the team:**
1. **Fill in domain specs** — replace stubs in `specs/` with actual business logic documentation
2. **Connect projects** — add `Blueprint Path: ../[BLUEPRINT_NAME]` to each project's `.memory/CONFIG.md`
3. **Run parity-check** — from each connected project to populate the parity matrix

---

## Notes

- Never modify application code in downstream projects during this workflow.
- If any step fails, report the error clearly and stop.
- The blueprint is a separate repo from all projects — it is NOT installed into projects. Projects _reference_ it via `Blueprint Path` in their CONFIG.md.
- The blueprint has no ai-memory branch. All persistent agent state lives in each project's own `.memory/`.
- Domain knowledge lives in `specs/` — project agents read specs directly via `[BLUEPRINT_PATH]/specs/`. The blueprint does NOT contain agent skills; those are installed per-project from agentskel.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
