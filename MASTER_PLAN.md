# agentskel — Architecture Decision Record (ADR)

> Corresponds to: agentskel v1.20

---

## 1. Vision

**agentskel** is a framework you install on existing projects to enable agentic
development. It gives every project an AI agent that remembers the codebase,
maintains standards, and keeps working across sessions — without re-learning
from scratch every time.

agentskel is an addon, not a starting point. Projects exist first. You add
agentskel when you want AI agents to work effectively on your codebase. It
scales from a solo developer with one project to an organization with dozens
of repos across platforms.

---

## 2. Problems We're Solving

| # | Problem | Impact |
|---|---------|--------|
| 1 | **Session amnesia** | AI agents lose context on session reset. Re-scanning a huge codebase every time wastes time and tokens. |
| 2 | **Codebase scale** | Large codebases can't fit in a context window. Agents need efficient navigation. |
| 3 | **Memory staleness** | Human devs change code between sessions. If the agent's index isn't updated, it works from wrong assumptions. |
| 4 | **No institutional knowledge** | Human developers carry domain knowledge in their heads. Agents start fresh — they don't know the business, the edge cases, or why things are the way they are. |
| 5 | **Cross-platform drift** | Business logic must stay in parity across platforms. Without coordination, implementations diverge silently. |
| 6 | **Standards at scale** | Multiple devs + AI agents = risk of style, quality, and architecture drift. |

---

## 3. Architecture Overview

### 3.1 Two Components

agentskel has two independent components. The skeleton is always required.
The blueprint is optional and only needed when multiple projects share
business domain knowledge.

```
Component 1: SKELETON (agentskel)              Component 2: BLUEPRINT (optional)
─────────────────────────────────              ──────────────────────────────────
Rules, workflows, skills, standards            Team domain knowledge
Installed per project into .agents/            Shared across projects
Versioned (sync-skeleton)                 Read on demand by agents

Your Project (after install)
┌─────────────────────────────────────────────────┐
│  .agents/        ← from skeleton (installed)    │
│  .memory/        ← project brain (per-repo)     │
│  CLAUDE.md       ← entry point                  │
│  src/            ← your code (untouched)        │
│                                                 │
│  CONFIG.md → Skeleton Path: ../agentskel        │
│              Blueprint Path: ../my-blueprint    │
└─────────────────────────────────────────────────┘
```

**Growth path:**
1. One project → install skeleton. No blueprint needed.
2. Domain knowledge grows → accumulates in `.memory/`.
3. Second project shares the same domain → create a blueprint repo.
   Move shared domain knowledge there. Both projects point to it.
4. Five projects → same pattern. Skeleton + blueprint. No fork required.

### 3.2 The Three-Tool Model

| Tool | Role | Who Uses It |
|------|------|-------------|
| **Antigravity** (IDE) | Agentic command center — planning, task orchestration, running agents | Tech leads, any dev doing AI-assisted work |
| **Claude Code / Gemini** (inside Antigravity) | The agent — reads memory, writes code, updates docs. Model is switchable mid-session. | Runs as directed from Antigravity |
| **Platform IDE** (Android Studio / Xcode / VS Code) | Manual development, building, testing, running, debugging | All 30 devs |

Antigravity is the primary interface for all agentic work from Day 1. Both Antigravity and platform IDEs point at the same local Git repo — file changes from agents are instantly visible in Android Studio/Xcode and vice versa.

When Claude runs out of context, you switch to Gemini (or any other model) in Antigravity's dropdown and continue working. The same rules, skills, workflows, and memory files carry over seamlessly because they are model-agnostic Markdown files.

---

## 4. Layer 1: Project Memory (Per-Repo)

### 4.1 The `ai-memory` Branch & Worktree

Each repo gets an orphaned Git branch called `ai-memory`. It is mounted locally via Git Worktree into a hidden `.memory/` directory.

**Initial setup (tech lead, one-time per repo):**
The `setup-skeleton` workflow handles this automatically — creating the orphan branch, mounting the worktree, populating memory files, and generating `scripts/install-agent.sh`.

**Developer setup (every developer, after cloning):**
```bash
./scripts/install-agent.sh
```
This script fetches remote branches, detects whether `origin/ai-memory` exists, and mounts the worktree automatically. If `.memory/` already exists, it pulls the latest changes from remote instead of exiting — so re-running the script refreshes memory. If the project hasn't been set up yet, it tells the developer to ask their tech lead.

Four scenarios this handles:
1. **Developer clones a project that already has ai-memory** — script mounts the worktree.
2. **Developer cloned before ai-memory existed** — script fetches the new branch and mounts it.
3. **Developer already has .memory/ mounted** — script pulls latest from remote.
4. **Project has never been set up** — script tells the developer to ask their tech lead to run `setup-skeleton`.

**Agent session-start behavior:**
If `.memory/` exists, the agent pulls the latest `ai-memory` from remote (`git -C .memory pull --ff-only`) before reading any memory files — ensuring all developers get the latest cartography and memory updates. If the pull fails (network, diverged history), it warns but proceeds with local copy. If `.memory/` is missing, it checks `git branch -r` for `origin/ai-memory` and directs the user to run `install-agent.sh` or `setup-skeleton` as appropriate. The agent refuses to work without memory files.

### 4.2 Project Memory Files

```
.memory/
├── RULES.md          # Project-specific context and rules (ad-hoc overrides)
├── MAP.md            # High-level architecture & module map
├── SYMBOLS.md        # Symbol registry (functions, classes → file paths)
├── RESUME.md         # Session state (always exists, never deleted)
├── CHANGELOG.md      # Agent-maintained log of changes and reasoning
├── TIME_LOG.md       # Effort tracking — estimated human hours vs agent duration
├── CONVENTIONS.md    # Project-specific coding patterns & conventions
├── LESSONS.md        # Agent mistake log — patterns to avoid
├── SACRED.md         # Intentional behaviors that must NEVER be changed
├── TECH_DEBT.md      # Categorized log of issues, anti-patterns, and debt
├── NEEDS_REVIEW.md   # Temporary triage queue for ambiguous patterns (emptied after review)
├── VERSIONS.md       # Current toolchain & dependency versions (updated after each upgrade)
├── DEPENDENCY_ALERTS.md  # Open major/security dependency alerts (surfaced at session start)
├── DEPENDENCY_HISTORY.md # Historical log of dependency upgrades
└── CONFIG.md         # Repo identity and operational config (skeleton version, check timestamps)
```

Canonical templates for all of the above live in agentskel:
`core/memory/` (memory templates), `core/rules/` (rule templates),
and `roles/dev/workflows/` (workflow templates).

The `setup-skeleton` workflow copies all templates into `.memory/` and
`.agents/` automatically from the skeleton (agentskel clone on disk).
Individual developers only need to run `scripts/install-agent.sh` to
mount the worktree — no skeleton clone or template knowledge required.

### 4.3 MAP.md

High-level architecture and module map. Contains architecture pattern, module registry (name → responsibility → key entry points), internal frameworks, and critical business logic flows traced to function-level entry points.

**Template:** `core/memory/MAP.md`

### 4.4 SYMBOLS.md

Public class and function registry, organized by module/framework. No line numbers — they go stale within minutes with 30 devs pushing code. Agents use ripgrep for precise location at query time.

**Template:** `core/memory/SYMBOLS.md`

### 4.5 RESUME.md

Session state file. Always exists, never deleted. Contains: Status (IDLE/IN_PROGRESS), last completed task, next task, persistent context notes, cartography state (last indexed commit SHA), and UTC timestamp. Updated after each sub-task and at session end.

**RESUME.md is local-only** — never committed or pushed. Each developer maintains their own session state independently.

**Template:** `core/memory/RESUME.md`

### 4.6 LESSONS.md

Agent mistake log. Each entry records: what went wrong, the pattern to avoid, and the rule to follow. Read at session start to prevent repeating mistakes.

**Template:** `core/memory/LESSONS.md`

### 4.7 SACRED.md

Records behaviors, workarounds, or patterns that look wrong but exist for a reason. The agent must never modify or refactor anything listed here without explicit human approval.

**The agent never decides something is sacred on its own.** During cartography and development, the agent classifies findings by confidence level. Obvious tech debt goes to TECH_DEBT.md. Patterns with strong evidence of intentionality (explanatory comments, recent deliberate commits, consistent usage) are auto-classified as sacred with High confidence. Ambiguous cases (Low confidence) go to NEEDS_REVIEW.md for human classification. See Section 4.10 for the full triage protocol.

**Template:** `core/memory/SACRED.md`

### 4.8 TECH_DEBT.md

Categorized registry of technical debt found during cartography and development. Categories: Anti-Patterns, Bugs, Missing Tests, Structural Issues, Dead Code. Each entry has an ID, module, description, severity, and discovery date. Input for future tech debt cleanup sprints.

**Template:** `core/memory/TECH_DEBT.md`

### 4.9 Checkpoint Protocol

> After completing each discrete sub-task:
> 1. Update RESUME.md with what was done and what's next.
> 2. Commit all changes in `.memory/` **except RESUME.md** to the `ai-memory`
>    branch with a descriptive message.
>
> At session end:
> 1. Write a final RESUME.md update.
> 2. Commit all `.memory/` changes except RESUME.md.
> 3. Push the `ai-memory` branch to origin.
>
> When a task is fully complete, set Status to IDLE and preserve Context
> Notes for the next session. Never delete RESUME.md.
>
> **RESUME.md is local-only.** It is never committed or pushed. Each
> developer maintains their own session state independently. All other
> memory files (MAP, SYMBOLS, TECH_DEBT, SACRED, LESSONS, etc.) are
> shared and must be committed and pushed.
>
> **Git commands for checkpointing:**
> ```bash
> cd .memory
> git pull origin ai-memory --rebase || true
> git add -A
> git reset HEAD RESUME.md
> git commit -m "agent: [descriptive message]"
> ```
>
> **Git commands for session end (commit + push):**
> ```bash
> cd .memory
> git pull origin ai-memory --rebase || true
> git add -A
> git reset HEAD RESUME.md
> git commit -m "agent: session end — [summary]"
> git push origin ai-memory
> ```
>
> To ensure RESUME.md is never accidentally committed, add it to
> `.memory/.gitignore`:
> ```
> RESUME.md
> ```
>
> Other developers pull the latest agent memory with:
> ```bash
> cd .memory && git pull origin ai-memory
> ```

### 4.10 Triage Protocol (SACRED vs TECH_DEBT Classification)

When the agent encounters a pattern that looks unusual, it classifies it
based on evidence — it does **not** decide something is sacred on its own.

**Classification signals:**
- **Likely sacred (High confidence):** Explanatory comment in code, recent
  deliberate commit with descriptive message (git blame), workaround pattern
  used consistently, references to device-specific or platform-specific issues.
- **Likely tech debt (High confidence):** No comment, old code untouched for
  years, FIXME/TODO markers, inconsistent with the rest of the codebase,
  clearly deprecated patterns.
- **Ambiguous (Low confidence):** No comment, but the pattern looks deliberate.
  Or there's a comment but it's unclear. Or the code is recent but the intent
  is uncertain.

**The flow:**
1. High-confidence tech debt → auto-classify into TECH_DEBT.md.
2. High-confidence sacred → auto-classify into SACRED.md with confidence marker.
3. Low-confidence / ambiguous → add to NEEDS_REVIEW.md with the agent's
   best guess and reasoning.
4. **At each module boundary** (after finishing mapping a module), the agent
   presents the NEEDS_REVIEW.md items from that module to the user for
   classification. This keeps batches small and digestible.
5. User classifies each item → agent moves it to SACRED.md or TECH_DEBT.md.
6. After cartography completes, NEEDS_REVIEW.md should be empty. Any
   remaining items are flagged in RESUME.md.

**Template:** `core/memory/NEEDS_REVIEW.md`

### 4.11 TIME_LOG.md (Effort Tracking & ROI Measurement)

Every development task (not cartography or review) gets a time log entry. The agent estimates how long a senior developer would take and records its own start/end timestamps. This data supports management decisions about agentic development ROI.

**Template:** `core/memory/TIME_LOG.md`

### 4.12 Memory Freshness & Drift Detection

As human developers push code, SYMBOLS.md and MAP.md can drift from
reality. The agent actively tracks and resolves this drift.

#### How the agent detects drift

RESUME.md contains a `Cartography State` section with the HEAD commit
SHA at which the last full indexing was done. At the start of every
session, the agent runs:

```bash
git log <last-indexed-commit>..HEAD --name-only --format=""
```

This lists every file changed since the last indexing. For any changed
file in an already-mapped module, that module is flagged as **stale**.
Stale modules are re-processed at the start of the session before the
main task begins.

#### During cartography (multi-session)

The cartographer records the HEAD commit SHA at the start of each
session in RESUME.md under `Cartography State`. Between sessions, if
new commits arrive in a module already mapped, the cartographer
re-checks those files before resuming the next module.

#### Post-cartography (ongoing)

**Short term (Phase 2, before GitHub Action):** The develop-feature
workflow (step 11) keeps SYMBOLS.md current for agent-driven changes.
For human-driven changes, the agent runs the drift check at session
start and re-reads stale modules before beginning its assigned task.

**Medium term (Phase 2, GitHub Action):** On merge to main, a GitHub
Action:
1. Runs `git diff HEAD~1..HEAD --name-only` to identify changed files.
2. Maps changed files to their owning modules.
3. Calls the Claude API with a targeted "re-map these modules" prompt
   (not a full re-cartography — only the changed files are re-read).
4. Commits updated SYMBOLS.md / TECH_DEBT.md entries to `ai-memory`.

This preserves the semantic understanding that the cartographer built
rather than replacing it with a dumb script.

#### Monthly full re-index

For each repo, schedule a full re-cartography monthly or at major
release boundaries to catch accumulated drift, validate SACRED.md
entries against current code, and remove TECH_DEBT.md items that
have been resolved.

#### Skeleton version drift

Beyond codebase drift, a project's agent setup can drift from the skeleton
(agentskel) as the framework evolves. This is tracked separately.

Each repo records its current skeleton version in `.memory/CONFIG.md`
(`Skeleton Version` field). Skeleton drift is detected two ways:

- **Session start:** the agent compares `Skeleton Version` in `.memory/CONFIG.md`
  against the current skeleton version. If they differ, `sync-skeleton` surfaces
  the delta for human review before development begins.
- **Periodic check (30-day cadence):** if `Last Skeleton Check` in `.memory/CONFIG.md`
  is more than 30 days old (or absent), the `check-skeleton` workflow runs at session
  start to detect drift proactively, even when versions appear in sync locally.

To read the current skeleton version, agents resolve the skeleton location in order:
1. `Skeleton Path` field in `.memory/CONFIG.md` — if set and the path exists on disk
2. Common sibling directory: `../agentskel`
3. If no local clone is found — offer to clone it or fall back to `gh api` GitHub fetch

The skeleton maintains `CHANGELOG.md` (at the repo root) — a running log of changes
grouped by version — so the agent knows exactly what changed and can present
each change as **apply / adapt / skip**. "Adapt" covers platform-specific
differences (e.g. the generic "run static analysis" step becomes
`./gradlew detekt --continue` on Android). "Skip" covers changes that are
intentionally not applicable, recorded as known deviations in `.memory/CONFIG.md`.

---

## 5. The Blueprint (Team Domain Knowledge)

### 5.1 What the Blueprint Is

The blueprint is an optional, separate repo that holds **team domain knowledge**
— the business logic, specs, and cross-platform coordination that a human
developer would carry in their head but an agent needs written down.

The blueprint contains **zero framework templates and zero application code**.
Framework templates (rules, workflows, skills, standards) live in agentskel.
Application code lives in each project. The blueprint fills the gap between
the two: the institutional knowledge that spans projects.

**The blueprint is a knowledge hub, not an agent workspace.** It has no
ai-memory branch and no persistent agent state. Project-specific agents
(e.g. the Muslim-Pro-Android agent) manage blueprint content by reading
and writing to it via `Blueprint Path` in their own `.memory/CONFIG.md`.
The blueprint includes a lightweight `.agents/` as a safety net if someone
opens it directly, but the primary workflow is remote management by
project agents.

**You don't need a blueprint to use agentskel.** For single-project teams,
all domain knowledge lives in the project's `.memory/`. Create a blueprint
only when multiple projects share the same business domain.

### 5.2 Blueprint Repo Structure

```
my-org-blueprint/
├── CONFIG.md                             # Blueprint identity (name, platforms, connected projects)
├── specs/                                # Business logic specs + API contracts
│   ├── prayer-times.md                   # (example: calculation algorithms, edge cases)
│   ├── auth-flow.md                      # (example: token rotation, session handling)
│   └── ...
├── parity/                               # Cross-platform feature tracking
│   └── PARITY_MATRIX.md
├── bus/                                  # Knowledge Bus (cross-project notifications)
│   ├── BUS_ENTRY_TEMPLATE.md
│   └── archive/                          # Processed entries (managed by janitor)
├── .agents/                              # Safety net — rules, subset of workflows, skills
├── .claude/skills/                       # Claude Code stubs
├── CLAUDE.md                             # Claude Code entry point (rules, config, domain refs)
├── GEMINI.md                             # Antigravity entry point (symmetric with CLAUDE.md)
├── VERSION                               # Blueprint version
└── CHANGELOG.md                          # Blueprint changelog
```

**No ai-memory branch.** The blueprint has no `.memory/` directory and no
orphan branch. A root-level `CONFIG.md` provides identity.

**How agents access it:** The project's `.memory/CONFIG.md` has a
`Blueprint Path` field pointing to the local clone. Agents read from it
on demand and write to it when domain knowledge changes (e.g. during
task-completion).

**How it's maintained:** Project-specific agents maintain it as a
byproduct of doing work. The task-completion skill checks: "Does this
work touch a documented domain area in the blueprint? If so, update it."
Agents can also propose new domain docs: "This logic seems like shared
knowledge. Should I document it in the blueprint?"

**How changes propagate:** At session start, each project agent pulls the
latest blueprint (`git -C [BLUEPRINT_PATH] pull`), compares commits since
`Last Blueprint Sync` in CONFIG.md, and surfaces any new spec or parity
changes to the developer. The Knowledge Bus provides semantic notifications
(what changed and what to do), while git-based detection is the safety net
that catches updates even when someone forgets to create a bus entry.

### 5.3 Parity Matrix

Lives in the blueprint. Tracks feature implementation consistency across platforms.

```markdown
# Cross-Platform Parity Matrix

| Business Logic | Android | iOS | Backend | Notes |
|---------------|---------|-----|---------|-------|
| Prayer Time Calc | v2.3 | v2.3 | v2.3 | |
| Qibla | v1.1 | v1.0 | N/A | iOS needs magnetic fix |
| Auth (OAuth2) | v3.0 | v3.0 | v3.0 | |
```

### 5.4 The Knowledge Bus

An append-only event log directory in the blueprint, maintained by agents.
Agents never edit existing files — they only create new ones. Git handles
concurrent new-file additions without merge conflicts.

When an agent makes a change that affects other platforms, it creates a bus
entry explaining what changed, why, and what action is needed.

**File naming:** `YYYYMMDD_HHMMSS_[AgentName]_[FeatureTag].md`

```
my-org-blueprint/bus/
├── 20260303_143005_AndroidAgent_AuthOptimization.md
├── 20260303_160000_iOSAgent_CompassFix.md
└── 20260304_091500_BackendAgent_TokenRotation.md
```

**Entry template:**
```markdown
# Knowledge Bus Entry

- **Timestamp:** 2026-03-03T14:30:05Z
- **Origin Agent:** Android Working Agent
- **Impact Level:** LOW | MEDIUM | HIGH
- **Target Platforms:** iOS, Backend

## Change Summary
[What changed and why]

## Cross-Platform Impact
[What other platforms need to do]

## Action Required
- [ ] iOS agent: [specific action]
- [ ] Backend agent: [specific action or "no action needed"]
```

**Janitor workflow (monthly):** Archives processed bus entries into a monthly
archive to keep the active `bus/` folder clean.

### 5.5 Repo Identity and Status

Each repo records its own identity in `.memory/CONFIG.md` (created during
`setup-skeleton`):

```markdown
## Identity

| Field | Value |
|-------|-------|
| Name | [project-name] |
| GitHub | [org/repo] |
| Platform | [Android / iOS / Backend / Web / ...] |
| Memory branch | ai-memory |
| Status | pilot |

## Operational Config

| Field | Value |
|-------|-------|
| Default Branch | [main / development / ...] |
| Skeleton Version | [SKELETON_VERSION] |
| Skeleton Path | (optional) path to local agentskel clone |
| Blueprint Path | (optional) path to local blueprint clone |
| Last Blueprint Sync | YYYY-MM-DDTHH:MMZ |
| Last Dependency Check | YYYY-MM-DDTHH:MMZ |
| Last Conventions Check | YYYY-MM-DDTHH:MMZ |
| Last Skeleton Check | YYYY-MM-DDTHH:MMZ |
```

**Status values:** `pilot` (setup done, cartography not yet complete) →
`active` (cartography complete, fully operational).

**Skeleton Version** is how agents detect framework drift — compared against
the current skeleton version at session start and on the 30-day
`check-skeleton` cadence.

**Skeleton Path** is optional: when set, skeleton workflows read files locally
instead of fetching from GitHub. Resolves in order: CONFIG.md field → sibling
directory `../agentskel` → GitHub fetch fallback.

**Blueprint Path** is optional: when set, agents read domain knowledge (specs,
parity, bus) from the blueprint. Only needed for multi-project teams with
shared domain knowledge.

**Last Blueprint Sync** is updated by `session-start` after reviewing blueprint
changes. Used to detect new blueprint commits since last session via
`git -C [BLUEPRINT_PATH] log --after="[date]"`.

---

## 6. The Multi-Tool Instruction System

### 6.1 The Problem

Agents enter the codebase via different tools — Claude Code (terminal), Antigravity (IDE), or any future tool that follows the `agentskills.io` open standard. Each tool has its own discovery mechanism for rules, skills, and entry points. Without a unified architecture, we'd need to maintain separate copies of every rule and skill per tool.

A second problem is **context compaction**. When an agent's context window fills up, older messages get compressed. Files read via tool calls (like `.memory/RULES.md`) get compacted away, causing agents to "forget" procedures mid-session. Only certain files survive compaction:
- **`CLAUDE.md`** / **`GEMINI.md`** — re-injected every turn in their respective tools
- **`.claude/skills/` descriptions** — YAML frontmatter loaded at startup, persists across compaction
- **`.agents/rules/`** — loaded as always-on context in Antigravity

Both entry points reference `.agents/rules/` (framework behavioral rules), `.memory/RULES.md` (project-specific context and rules), `.memory/RESUME.md` (session state), and the three procedural skill triggers. The `session-start` skill handles reading all other `.memory/` files — entry points don't list them individually to avoid dual-inventory maintenance.

This means **principles** (short, always-on) belong in rules, but **procedures** (step-by-step checklists) need a different approach: they should load just-in-time via skills, not sit in rules waiting to be forgotten.

### 6.2 Design Principles

1. **Single source of truth**: `.agents/` (plural) contains all rules, skills, and workflows. Other directories point to it.
2. **Tool-specific entry points**: Each tool gets a thin entry point file (`CLAUDE.md`, `GEMINI.md`) that bootstraps the agent into the shared system.
3. **Tool-specific discovery shims**: Each tool gets a discovery directory (`.claude/skills/`, `.agent/`) that maps to `.agents/`.
4. **Rules are principles**: Short, always-active statements that survive compaction. No step-by-step procedures.
5. **Skills are procedures**: Step-by-step checklists with gates. Loaded just-in-time when the task requires them. Descriptions survive compaction; full content loads fresh.
6. **Workflows are missions**: Multi-step, user-triggered operations (cartographer, sync-skeleton, etc.).
7. **Symlinks for skeleton/blueprint repos, copies for projects**: Repos that contain source templates (`core/`, `roles/`) use symlinks in `.agents/` pointing to those templates — zero internal drift. Downstream projects (which don't have `core/` or `roles/`) use copies created during setup.
8. **`repo-rules.md` for project-specific rules**: Each project can have a `.agents/rules/repo-rules.md` for rules unique to that repo (e.g. architecture documentation requirements, domain constraints). This file has no upstream template and is never overwritten by setup or sync.

### 6.3 Entry Points by Tool

| Tool | Entry Point | Discovery Directory | How It Works |
|------|------------|-------------------|-------------|
| **Claude Code** | `CLAUDE.md` | `.claude/skills/` | `CLAUDE.md` survives compaction (re-injected every turn). Contains procedural skill triggers, `.agents/rules/` reference (framework rules), `.memory/RULES.md` (project context and rules), and `.memory/RESUME.md` (session state). All other `.memory/` files are read by `session-start`. `.claude/skills/` stubs have YAML descriptions (~1 line each) that Claude loads at startup — descriptions survive compaction, full skill content loads on-demand via a redirect to `.agents/`. |
| **Antigravity** | `GEMINI.md` | `.agent/` (symlink → `.agents/`) | `GEMINI.md` survives compaction (re-injected every turn). Contains `.agent/rules/` and `.agent/skills/` references (framework rules + skill discovery), procedural skill triggers, `.memory/RULES.md` (project context and rules), and `.memory/RESUME.md` (session state). All other `.memory/` files are read by `session-start`. The `.agent` symlink points to `.agents/` so both tools share the same files. |
| **agentskills.io** | — | `.agents/` | The open standard (`agentskills.io`) specifies `.agents/skills/` format. Portable across Claude Code, Antigravity, Cursor, Codex, Kiro. This is the canonical directory. |

### 6.4 Repo File Structure

```
repo-root/
├── CLAUDE.md                              ← Claude Code entry point (survives compaction)
├── GEMINI.md                              ← Antigravity entry point
├── .claude/
│   └── skills/                            ← Claude Code auto-discovery (stub files)
│       ├── session-start.md               ← "Read .agents/skills/session-start/SKILL.md"
│       ├── task-completion.md
│       ├── git-flow.md
│       ├── senior-developer.md
│       ├── develop-feature.md
│       └── ... (auto-generated from skills + workflows)
├── .agent -> .agents                      ← Symlink for Antigravity native discovery
├── .agents/                               ← Single source of truth (agentskills.io)
│   ├── rules/
│   │   ├── core-behavior.md               ← Always on: principles, communication, errors
│   │   ├── security-non-negotiables.md    ← Always on: hard security rules
│   │   └── repo-rules.md                  ← Project-specific rules (never overwritten by sync)
│   ├── skills/
│   │   ├── senior-developer/SKILL.md      ← Domain: code quality, SOLID, UX
│   │   ├── test-engineer/SKILL.md         ← Domain: testing, CI/CD
│   │   ├── code-reviewer/SKILL.md         ← Domain: PR review, QA
│   │   ├── task-planner/SKILL.md          ← Domain: decomposition, tracking
│   │   ├── prayer-time-expert/SKILL.md    ← Domain: prayer time business logic
│   │   ├── session-start/SKILL.md         ← Procedural: session initialization
│   │   ├── task-completion/SKILL.md       ← Procedural: post-task checklist
│   │   └── git-flow/SKILL.md             ← Procedural: branching, commit, PR
│   └── workflows/
│       ├── cartographer.md
│       ├── develop-feature.md
│       ├── implement-task.md
│       ├── fix-tech-debt.md
│       ├── hotfix.md
│       ├── sync-skeleton.md
│       ├── check-dependencies.md
│       └── ... (8 more workflows)
└── .memory/                               ← Git worktree (ai-memory branch)
    ├── CONFIG.md                          ← Repo identity, skeleton version, check timestamps
    ├── RULES.md                           ← Project-specific context and rules
    ├── MAP.md                             ← Module and architecture map
    ├── SYMBOLS.md                         ← Public classes and functions index
    ├── RESUME.md                          ← Session state (local-only, not committed)
    ├── CHANGELOG.md, TIME_LOG.md          ← Change history and effort tracking
    ├── LESSONS.md, SACRED.md              ← Learning and protected behaviors
    ├── NEEDS_REVIEW.md                    ← Triage queue for ambiguous patterns
    ├── CONVENTIONS.md, TECH_DEBT.md       ← Code style and debt tracking
    ├── VERSIONS.md                        ← Toolchain and dependency versions
    ├── DEPENDENCY_ALERTS.md               ← Open major/security dependency alerts
    └── DEPENDENCY_HISTORY.md              ← Historical log of dependency upgrades
```

### 6.5 The Stub Pattern (Claude Code)

Claude Code auto-discovers skills from `.claude/skills/`. Each stub file is ~3 lines:

```markdown
---
description: Post-task checklist — CHANGELOG, TIME_LOG, SYMBOLS/MAP updates,
  RESUME update, memory commit. Must run after completing any development task.
---

Read and follow the full skill at `.agents/skills/task-completion/SKILL.md`.
```

**Why stubs?** The YAML `description` field is loaded at Claude Code startup and survives context compaction. When the skill is triggered, Claude reads the full procedure fresh from `.agents/`. This solves the "forgotten procedures" problem — the agent always knows the skill exists (description persists) and loads the full steps just-in-time (never stale from compaction).

### 6.6 How Rules, Skills, and Memory Interact

```
Session start:
  CLAUDE.md (or GEMINI.md)
    → triggers session-start skill
      → reads .memory/CONFIG.md, RULES.md, MAP.md, SYMBOLS.md, etc.
      → checks skeleton version, dependency freshness, git state
      → reports ready

During work:
  .agents/rules/ (always active — principles)
  + .agents/skills/ (loaded on demand — domain knowledge + procedures)
  + .agents/workflows/ (triggered by user — multi-step missions)

Task complete:
  → triggers task-completion skill
    → CHANGELOG, TIME_LOG, SYMBOLS/MAP, RESUME, memory commit

Session end:
  → commit and push .memory/ to ai-memory branch
```

---

## 7. Agent Behavior System (Rules, Skills, Workflows)

The right behavior activates at the right time. Not everything applies to every task.

| Mechanism | Activation | Use For | Survives Compaction? |
|-----------|-----------|---------|---------------------|
| **Rules** (always-on) | Every conversation | Principles: core behavior, security, communication | Yes (loaded as context) |
| **Domain skills** (contextual) | Agent decides based on task | Standards: coding, testing, review, domain knowledge | Description yes; full content loads on-demand |
| **Procedural skills** (triggered) | Specific moments (session start, task end, git ops) | Step-by-step checklists with gates | Description yes; full content loads on-demand |
| **Workflows** (explicit) | User invokes via `/command` or description | Multi-step missions | Loaded when triggered |

**Why the split?** In v3, procedures (session initialization, task completion checklists, git flow steps) were embedded in rules. Rules are read once at session start. When the context window fills up and compacts, those procedures get forgotten — the agent skips TIME_LOG, forgets to check skeleton version, commits directly to main.

In v4, rules contain only **principles** (short, memorable, always-active). Procedures are extracted into **procedural skills** with explicit checkpoints and gates. The agent always knows the skill exists (description survives compaction) and loads the full procedure just-in-time when needed.

Domain skills remain unchanged — specialist knowledge (coding standards, testing, review, prayer times) that the agent loads when the task requires it.

### 7.1 Always-On Rules

#### .agents/rules/core-behavior.md

Contains principles only — no step-by-step procedures. Procedures are in skills. Sections: How You Work (includes "Never assume" — verify before concluding something is missing; "Use your memory" — when MAP.md and SYMBOLS.md exist, use them to locate files instead of re-scanning the codebase (since v1.13); "Every task follows a workflow" — route to matching workflow or default to `implement-task`; "Plan first" — all tasks require plan + explicit approval, no exceptions since v1.12), Task Completion (mandatory `task-completion` skill gate), Git and File Discipline (no changes during discussion, no commits without instruction, complete git flow once started), How You Communicate, How You Handle Errors, Memory Protocol (`session-start` at session start, `task-completion` after tasks, checkpoint protocol), Skeleton Contribution (6-item checklist: VERSION bump, CHANGELOG entry, README version line, MASTER_PLAN update if structural, self-sync `.agents/` copies when Skeleton Path = `.`, update CONFIG.md Skeleton Version), Effort Tracking (estimate human hours, record in RESUME.md before starting — survives compaction since v1.11), Dependency Boundaries (never upgrade without instruction, read release notes, major upgrades need plan — survives compaction since v1.11), Content Preservation (never replace detailed instructions with generic summaries — state reasoning and get approval before simplifying; applies to all files in core/, roles/, .agents/, .memory/, and blueprints — since v1.12), Blueprint Contribution (if configured).

**Source:** `core/rules/core-behavior.md`

#### .agents/rules/security-non-negotiables.md

Hard security rules that apply to every task without exception. Covers: no hardcoded credentials, no logging secrets, input validation, no eval/command injection, least privilege, file scope limits, no mock data in production.

**Source:** `core/rules/security-non-negotiables.md`

### 7.2 Contextual Skills

Skills are loaded only when the agent determines they're relevant to the current task. The agent sees a one-line description at session start (~50 tokens per skill) and loads full instructions only when needed.

**Platform markers (v1.1):** Three domain skills (`senior-developer`, `code-reviewer`, `test-engineer`) contain `<!-- PLATFORM: X -->` / `<!-- END PLATFORM: X -->` HTML comment markers — the same mechanism used in standards. During `setup-skeleton`, sections for irrelevant platforms are stripped so the installed skill only contains guidance for the project's platform. `sync-skeleton` re-trims after updating from the skeleton source.

#### .agents/skills/senior-developer/SKILL.md

Generic sections (User Experience, Design Philosophy, SOLID, Code Quality, Process, System Extension) plus a `## Platform Standards` section with `<!-- PLATFORM: X -->` markers for Android (Compose/UDF, Coroutines, Detekt), iOS (SwiftUI, async/await, SwiftLint), Web (TypeScript, ESLint), and Backend (generic async/linting). Platform sections are trimmed during `setup-skeleton` — a project installed for Android only sees the Android block. Since v1.13, Code Quality includes explicit cleanup rules (unused imports, unused variables, dead code removal, import organization per STYLE_GUIDE) and per-platform static analysis is conditional ("if the project uses X") rather than mandatory.

#### .agents/skills/test-engineer/SKILL.md

Generic sections (Testing Rules, Verification, Error Handling Design) plus a `## Test Structure` section with `<!-- PLATFORM: X -->` markers for Android (MockK, Espresso, backtick naming), iOS (XCTest, XCUITest), Web (Jest/Vitest, Playwright), and Backend (standard framework). Platform sections are trimmed during `setup-skeleton`.

#### .agents/skills/code-reviewer/SKILL.md

Review Checklist (10 items), Documentation Standards, QA Procedures, and Feedback guidelines. Checklist items 4 (Architecture), 5 (Lint/Static Analysis), and 10 (Dependencies) contain `<!-- PLATFORM: X -->` markers with platform-specific tool and file references. Platform sections are trimmed during `setup-skeleton`. **Blueprint awareness (v1.2):** `## Cross-Platform Impact` checklist — if blueprint is configured, verify changes match specs, flag shared logic changes needing bus entries, check parity status.

#### .agents/skills/task-planner/SKILL.md

Task Management (6-step plan-first process), Task Quality, Change Tracking, and Subagent Strategy sections. **Blueprint awareness (v1.2):** `## Blueprint Check` section — if blueprint is configured and task involves shared business logic, read specs and parity matrix before planning, include "Requires Knowledge Bus entry" in plans when applicable, note spec gaps.

#### .agents/skills/prayer-time-expert/SKILL.md

Project-specific domain skill (not part of skeleton templates). Example of a custom domain expert skill — covers prayer time calculation constraints, Athan scheduling, references to blueprint specs and SACRED.md entries. Each project creates its own domain expert skills as needed.

### 7.2b Procedural Skills (v4.0)

Procedural skills are step-by-step checklists with explicit gates. Unlike domain skills (which provide standards and guidelines), procedural skills enforce **specific sequences of actions** that must be completed in order. Each step has a checkbox; the skill includes a gate at the end that prevents the agent from proceeding until all applicable steps are done.

These were extracted from rules in v4.0 because procedures embedded in rules got forgotten after context compaction.

| Skill | Trigger | What It Enforces |
|-------|---------|-----------------|
| `session-start` | Beginning of every session | Memory mount check → pull latest ai-memory from remote → read all memory files (incl. NEEDS_REVIEW.md) → surface alerts and triage items → check skeleton version → check freshness timestamps (incl. blueprint staleness >7 days) → check blueprint (pull latest, detect changes since Last Blueprint Sync, check Knowledge Bus for unprocessed entries targeting this platform) → check git state → confirm ready |
| `task-completion` | After completing any development task | CHANGELOG → SYMBOLS/MAP → TIME_LOG → Knowledge Bus (commit+push to blueprint repo) → README (skeleton only) → Migration Step (skeleton, breaking only) → MASTER_PLAN (skeleton only, v1.11: reads trigger list from MAINTAIN_MASTER_PLAN.md, states which matched) → Self-sync verification (skeleton only, v1.10: diff sources vs `.agents/` copies, check CONFIG.md version) → RESUME → memory commit → **Completion summary** (v1.11: lists steps executed and skipped with reasons) |
| `git-flow` | When creating branches, committing, or opening PRs | Branch from default → correct naming → commit message format → push → open PR → never merge own PR |

Each procedural skill lives in `.agents/skills/<name>/SKILL.md` with the same YAML frontmatter as domain skills. In Claude Code, the `.claude/skills/` stub ensures the description survives compaction.

**Example gate** (from task-completion):
```
Gate: Do not respond to the user or start the next task until all applicable
steps above are checked off. If a step was skipped, note why.
```

### 7.3 Workflows

Invoked explicitly via `/workflow-name` in Antigravity's chat (or by description in Claude Code). Each workflow specifies its scope and what to skip.

#### .agents/workflows/cartographer.md

Discovery mission that maps the codebase into MAP.md, SYMBOLS.md, and TECH_DEBT.md. Multi-session capable (tracks progress in RESUME.md). Processes each module one at a time: reads source files, extracts symbols, classifies findings via the Triage Protocol (Section 4.10), pauses for human review of ambiguous items at each module boundary. If the project has a MASTER_PLAN.md or similar ADR, indexes its sections into MAP.md (section name, line range, 1-line summary) so agents can read specific sections via offset/limit. Read-only — never modifies application code.

**Source:** `roles/dev/workflows/cartographer.md`

#### .agents/workflows/develop-feature.md

Full feature development lifecycle: Pre-Flight (read memory files, understand requirements) → Phase 1: Plan (write plan with estimates, wait for approval) → Phase 2: Implement (follow senior-developer standards, respect SACRED.md, update SYMBOLS/MAP) → Phase 3: Test (follow test-engineer standards, verify tests pass) → Phase 4: Document (CHANGELOG, TIME_LOG, Knowledge Bus if blueprint configured, memory commit).

**Source:** `roles/dev/workflows/develop-feature.md`

#### .agents/workflows/implement-task.md (v1.9, updated v1.12)

Generic wrapper for any ad-hoc implementation request (fix, change, add, remove, refactor) that doesn't match a named workflow. Pre-Flight (read memory files) → Plan (write plan scaled to task size, present to user, **wait for explicit approval — no exceptions**, no trivial-task bypass since v1.12) → Branch (create branch per git-flow before writing code — moved from Phase 4 since v1.12) → Implement (follow senior-developer standards) → Verify (follow test-engineer standards since v1.12, run tests if available) → Complete (commit, PR via git-flow, task-completion). Exists to close the enforcement gap where ad-hoc tasks could skip the post-task checklist — named workflows embed task-completion as their final step, but requests that don't match any workflow had no structural wrapper.

**Source:** `roles/dev/workflows/implement-task.md`

#### .agents/workflows/parity-check.md

Compares business logic across platforms for consistency. Reads blueprint specs and PARITY_MATRIX.md, compares against this repo's implementation, flags deviations, updates the matrix, and creates Knowledge Bus entries for cross-platform action items. Run reactively (after bus alerts) or proactively (bi-weekly cadence) by tech leads.

**Source:** `roles/dev/workflows/parity-check.md`

#### .agents/workflows/create-blueprint.md (v1.2, updated v1.4-v1.6)

Sets up a new blueprint repository — the shared domain knowledge layer for
multi-project teams. Creates `specs/`, `parity/`, `bus/`, and a
lightweight `.agents/` safety net. No ai-memory branch — the blueprint is a
knowledge hub managed by project-specific agents via `Blueprint Path`.

Key design decisions:
- Root-level `CONFIG.md` instead of `.memory/CONFIG.md` (no memory branch)
- `.agents/` includes only: rules, git-flow skill, task-planner skill (trimmed),
  blueprint-specific session-start skill, sync-skeleton/check-skeleton workflows (trimmed)
- Skips senior-developer, session-start (project version), task-completion,
  test-engineer, code-reviewer, domain-expert (all require `.memory/` or are code-focused)
- Symmetric `CLAUDE.md` and `GEMINI.md` entry points — both reference `.agents/rules/`,
  `CONFIG.md`, `specs/`, `parity/`, `bus/`, and skill triggers (v1.17)
- Blueprint trimming rules for all copied files (v1.5): remove `.memory/` refs,
  code-specific sections, session lifecycle refs
- sync-skeleton includes Step 5x migration mechanism for breaking changes (v1.6)

**Source:** `roles/dev/workflows/create-blueprint.md`

#### Finalized in v1.3: cut-release workflow and API Contract standard

**`roles/dev/workflows/cut-release.md`** — Pre-flight checks, CI trigger, release notes generation, dependency snapshot (legal compliance), human approval gate, build trigger, post-merge cleanup. Platform-specific sections trimmed during setup.

**`roles/dev/standards/API_CONTRACT.md`** — Full standard covering: URL-prefix versioning, JSON request/response envelope, error format with status code mapping, Bearer token auth, rate limiting, cursor-based pagination, breaking change policy with 90-day deprecation.

### 7.4 Token Budget

Base cost: always-on rules (~2,400 tokens) are loaded in every scenario.

| Scenario | What's Loaded | Est. Tokens |
|----------|--------------|-------------|
| Cartographer mission | Always-on rules + workflow | ~4,700 |
| Simple bug fix | Always-on rules + senior-developer skill | ~3,900 |
| Feature development | Always-on rules + senior-dev + test-engineer + task-planner | ~4,900 |
| Code review | Always-on rules + code-reviewer skill | ~3,400 |
| Session start | Always-on rules + session-start skill | ~4,200 |
| Task completion | Always-on rules + task-completion skill | ~3,900 |
| All skills active (worst case) | Everything | ~8,000 |

The full memory system (15 files including MAP.md, SYMBOLS.md, RESUME.md, RULES.md, LESSONS.md, SACRED.md, CONVENTIONS.md, CONFIG.md, VERSIONS.md, TECH_DEBT.md, NEEDS_REVIEW.md, CHANGELOG.md, TIME_LOG.md, DEPENDENCY_ALERTS.md, DEPENDENCY_HISTORY.md) for a large repo should stay under **30KB (~7,500 tokens)** — still a small fraction of the context window.

Note: In Claude Code, `.claude/skills/` stubs add ~23 × 60 = **~1,400 tokens** to the persistent context (descriptions only). This is the cost of surviving compaction — well worth it for reliable procedure execution.

### 7.5 Antigravity Knowledge Items

Antigravity has a built-in Knowledge system that auto-captures insights across conversations. This is **complementary** to the `.memory/` memory:

| System | Scope | Persistence | Contents |
|--------|-------|-------------|----------|
| `.memory/` memory | Per-repo, Git-versioned, shared | Permanent | Structured codebase knowledge |
| Antigravity Knowledge Items | Per-user, in Antigravity | Persistent across conversations | Conversational insights |

The `.memory/` system is the source of truth. Knowledge Items are a bonus for individual productivity but are not shared or version-controlled.

---

## 8. Git Workflow

The full workflow specification lives at:
**`roles/dev/standards/GIT_WORKFLOW.md`** (in agentskel, installed to all projects during setup)

### Summary for agents

| Scenario | Base | Branch name | Merge strategy |
|----------|------|-------------|----------------|
| Feature / bug / chore (human) | `development` | `BOARD-XXXX-description` | Squash |
| Feature (agent, JIRA ticket given) | `development` | `BOARD-XXXX-description` | Squash |
| Tech debt fix (agent, no JIRA ticket) | `development` | `debt-id-description` | Squash |
| Release | `development` | `release/x.y.z` | Merge commit |
| Hotfix (release open) | `release/x.y.z` | `BOARD-XXXX-description` | Squash → release |
| Hotfix (after merge-back) | tagged commit | `release/x.y.z+1` | Merge commit |

### Key rules
- `development` is the base branch — no direct pushes
- All merges via PR — minimum 1 approval + CI pass
- Commit message format: `[BOARD-XXXX] short description` or `[BUG-009] short description`
- Tags applied on `development` after release merges back: `git tag v9.8.0`
- Agent never creates JIRA tickets — PM creates them; agent uses the given `BOARD-XXXX` ID
- Tech debt branches use `TECH_DEBT.md` IDs directly (no JIRA needed)

---

## 9. Dependency & Toolchain Management

The full policy lives at:
**`roles/dev/standards/DEPENDENCY_MANAGEMENT.md`** (in agentskel, installed to all projects during setup)

### 9.1 Platform-Specific Architecture Standards (v1.1)

In addition to the 5 universal standards (ARCHITECTURE, GIT_WORKFLOW, STYLE_GUIDE, DEPENDENCY_MANAGEMENT, API_CONTRACT), agentskel provides platform-specific architecture templates:

- **`roles/dev/standards/ANDROID_ARCHITECTURE.md`** — Compose/UDF, Hilt DI, Compose Navigation, module graph, data layer patterns. Installed only for Android projects.
- **`roles/dev/standards/IOS_ARCHITECTURE.md`** — SwiftUI, NavigationStack, Swift Concurrency, SPM module structure, data layer patterns. Installed only for iOS projects.

These are installed conditionally during `setup-skeleton` based on the project's platform. They complement the universal `ARCHITECTURE.md` (which covers platform-agnostic principles) with platform-specific implementation guidance.

### Summary for agents

Never upgrade Gradle, AGP, Kotlin, SDK levels, iOS targets, or any library version as a side-effect of another task. Upgrades are deliberate, isolated PRs.

**Before any upgrade:** read the official release notes for the target version. Release notes URLs are recorded in `.memory/VERSIONS.md`. Never rely on version numbers alone — release notes reveal behaviour changes, deprecations, and migration steps.

**For Tier 3/4 (major) upgrades:** read release notes for every version between current and target, write a full upgrade plan, and present it to the developer for approval before touching any file. The plan is the deliverable; the human decides whether to proceed.

| Tier | Examples | Approver |
|------|---------|----------|
| Patch | Library bugfix release | Any dev — normal PR |
| Minor | Gradle 8.5→8.6, AGP 8.2→8.3 | Tech lead review |
| Major/Technical | Kotlin 1.x→2.x, AGP 7.x→8.x, Gradle major | Lead engineer (CODEOWNERS enforced) |
| Major/Business | `minSdk` bump, iOS deployment target bump | Lead engineer + PM |

### CODEOWNERS enforcement

Toolchain version files in each repo are owned by the lead engineer in `.github/CODEOWNERS`. GitHub will not allow merge without their approval — this is structural enforcement, not process-based.

### VERSIONS.md and CONFIG.md

Each repo maintains two operational files:

- **`.memory/VERSIONS.md`** — snapshot of current toolchain and dependency versions, flags for items needing attention, and an upgrade log. Template: `core/memory/VERSIONS.md` in agentskel.
- **`.memory/CONFIG.md`** — repo identity (name, GitHub slug, platform, description, status) and operational config (default branch, skeleton version, optional skeleton path, optional blueprint path, last blueprint sync date, last dependency check date, last conventions check date, last skeleton check date). Template: `core/memory/CONFIG.md` in agentskel.

Agents read both files at session start. `CONFIG.md` is the source of truth for skeleton version drift detection and workflow trigger dates.

---

## 10. Layer 3: Orchestration

### 10.1 GitHub Actions — Memory Maintenance

**Trigger:** On push to `development` or `main` branch.

```yaml
# .github/workflows/agent-memory-update.yml
name: Update Agent Memory

on:
  push:
    branches: [development, main]

jobs:
  update-memory:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Generate diff summary
        run: |
          git diff HEAD~1 --name-only > changed_files.txt
          git diff HEAD~1 --stat > diff_summary.txt

      - name: Update SYMBOLS.md
        run: |
          # Phase 1: Script-based (ctags/tree-sitter) — deterministic, cheap
          # Phase 2: Upgrade to Claude API call for smarter updates
          ./scripts/update-symbols.sh

      - name: Commit memory updates
        run: |
          cd .memory
          git add -A
          git commit -m "auto: memory update from ${GITHUB_SHA::7}" || true
          git push origin ai-memory
```

### 10.2 GitHub Actions — Knowledge Bus Notifications

**Trigger:** On push to the blueprint repo when new files appear in `bus/`.

Parses new bus entries, extracts Impact Level and Target Platforms, and posts to Slack with appropriate urgency.

### 10.3 Slack Channels

| Channel | Purpose | Trigger |
|---------|---------|---------|
| `#dev-agent-pulse` | Agent activity log | GitHub Action on ai-memory push |
| `#dev-agent-reviews` | PR review comments from Reviewer Agent | GitHub Action on PR creation |
| `#dev-agent-parity` | Cross-platform sync alerts | GitHub Action on new bus/ entry |

### 10.4 Reviewer Agent (Hybrid Model)

**Phase 1 (Advisory):** The reviewer agent runs on PR creation via GitHub Action. It compares changes against the project's installed style guide and the `code-reviewer` skill. Comments are posted to the PR and routed to `#dev-agent-reviews`.

**Phase 2 (Hard Gate):** Once the false positive rate is below an acceptable threshold after **4 weeks OR 50 PRs reviewed (whichever comes first)**, the reviewer becomes a required check for merge. These thresholds will be configurable (configuration mechanism TBD — not yet implemented in the skeleton).

---

## 11. Recommended Adoption Path

### Phase 0: Foundation

**Goal:** Install agentskel on your first project.

- [ ] Clone agentskel locally
- [ ] Run `setup-skeleton` workflow on your project, pointing to agentskel clone
- [ ] Verify: `.agents/`, `.memory/`, `CLAUDE.md`, `GEMINI.md` created
- [ ] Verify platform-specific standards installed (ANDROID_ARCHITECTURE.md / IOS_ARCHITECTURE.md)
- [ ] Verify skill platform markers trimmed for your platform

### Phase 1: The Cartographer

**Goal:** Map the codebase. Prove the memory system works.

- [ ] Run the `/cartographer` workflow
- [ ] Review MAP.md, SYMBOLS.md, TECH_DEBT.md for accuracy
- [ ] Review SACRED.md for flagged intentional behaviors
- [ ] Test session continuity: end session, start new, verify RESUME.md pickup
- [ ] **Success criteria:** Agent navigates the codebase without full scan.

### Phase 2: Working Agent

**Goal:** Use agents for real development tasks.

- [ ] Assign 2-3 real tasks (bug fixes or small features)
- [ ] Test LESSONS.md: correct the agent, verify it learns
- [ ] Test SACRED.md: verify the agent respects protected behaviors
- [ ] Set up GitHub Action for automated memory updates on push (optional)
- [ ] **Success criteria:** Tasks complete faster than cold-start.

### Phase 3: Multi-Project (optional)

**Goal:** Add a second project and shared domain knowledge.

- [ ] Install agentskel on the second project
- [ ] Run the `create-blueprint` workflow to set up the blueprint repo
  (creates specs/, parity/, bus/, .agents/ safety net, CONFIG.md)
- [ ] Move shared specs/skills from project `.memory/` to blueprint's `specs/`
- [ ] Configure `Blueprint Path` in both projects' `.memory/CONFIG.md`
- [ ] Verify session-start detects blueprint (Step 6a: change detection, Step 6b: bus check)
- [ ] Enable Knowledge Bus for cross-project coordination
- [ ] **Success criteria:** Domain change in one project generates bus entry;
  next session on the other project surfaces it automatically.

### Phase 4: Scale

**Goal:** Roll out to remaining projects.

- [ ] Repeat Phase 1-2 for each project
- [ ] Populate PARITY_MATRIX.md
- [ ] Set up parity check cadence
- [ ] Enable reviewer agent (advisory mode first)

---

## 12. Extension Points

agentskel is designed to extend without modifying the core framework:

- **`repo-rules.md`** — project-specific rules that survive skeleton syncs
- **Blueprint repo** — shared domain knowledge, parity, bus (optional)
- **`roles/devops/`** — DevOps agent role (planned)
- **Custom skills** — add domain expert skills per project or in the blueprint
- **GitHub Actions** — automated memory updates, bus notifications, reviewer agent
- **MCP servers** — live infrastructure queries, database schema awareness

---

## 13. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| SYMBOLS.md drifts from reality | Medium | Medium | GitHub Action auto-updates on push; monthly full re-index |
| Agent hallucinates architecture in MAP.md | Low-Medium | High | Human review of initial MAP.md; flag confidence levels |
| Reviewer Agent false positives | Medium | High | Advisory-only first; track false positive rate before gating |
| Knowledge Bus creates noise | Medium | Low | Clear templates; human curation of entries; monthly Janitor |
| Developers resist agent output | Medium | High | Start with pilot volunteers; show measurable time savings |
| ai-memory branch conflicts | Low | Medium | Agent is sole writer; humans review but don't edit directly |
| LESSONS.md / SACRED.md grow too large | Low | Medium | Quarterly review cadence with Slack scheduled reminder to `#dev-agent-pulse`; archive lessons older than 6 months that have been consistently followed; keep SACRED.md curated |
| Agent ignores SACRED.md entries | Low | High | Always-on rule references SACRED.md; code-reviewer skill checks for violations |
