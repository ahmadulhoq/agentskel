# agentskel

> Install agentic development on any existing project — persistent memory, shared standards, and structured workflows for AI coding agents.

AI coding agents (Claude Code, Antigravity, Cursor, Copilot) are powerful but stateless: they forget everything between sessions, make inconsistent decisions, and have no awareness of what other parts of your codebase are doing.

**agentskel** fixes this. It gives every project a structured foundation — memory that persists across sessions, rules the agent always follows, skills it can invoke on demand, and workflows for complex multi-step tasks. Install it on your existing projects. No fork required.

**This repo contains zero application code.** It's pure infrastructure for AI agents.

```
agentskel (skeleton)                    Your Project (after install)
─────────────────                       ────────────────────────────
Rules, workflows, skills, standards     .agents/   ← copied from skeleton
Versioned (sync-skeleton)          .memory/   ← project brain (per-repo)
                                        CLAUDE.md  ← entry point

Optional:
my-blueprint (team domain knowledge)
────────────────────────────────────
Specs, parity matrix, knowledge bus
Shared across projects
Read on demand by agents
```

---

## Problems this solves

| Problem | How agentskel solves it |
|---------|------------------------|
| **Agents forget everything between sessions** | Every project gets a `.memory/` branch — MAP, SYMBOLS, RESUME, LESSONS — that persists across sessions. The agent maps every class and function so it can find things directly, without re-scanning |
| **No shared standards** | Every agent reads the same standards (architecture, git workflow, style, dependency policy) before every task — no inconsistent decisions |
| **Agents re-explore the same code every time** | The Cartographer builds a permanent index of modules, classes, and functions. The agent reads this index instead of re-scanning |
| **Agent setup goes stale as the skeleton evolves** | Each project tracks its skeleton version. When agentskel is updated, agents detect the gap and the `sync-skeleton` workflow walks through each change via a reviewed PR |
| **Multiple platforms diverge silently** | The parity matrix (in your optional blueprint) tracks which platform implements which feature. Agents check the matrix before cross-platform changes |

---

## Two components

### Skeleton (always required)

**agentskel** is the skeleton — rules, workflows, skills, and standards that get installed on your projects. It contains no business logic, no org-specific standards, and no product knowledge.

You clone agentskel once. Every project on the same machine shares a single clone. When agentskel is updated, each project's agent detects the version gap and walks through changes with the tech lead.

### Blueprint (optional — for multi-project teams)

When multiple projects share the same business domain (e.g. Android app, iOS app, and backend for the same product), you create a **blueprint** repo — a shared store of domain knowledge that agents read on demand.

The blueprint contains:
- **Domain specs** — business logic, API contracts, edge cases
- **Parity matrix** — tracks feature consistency across platforms
- **Knowledge Bus** — cross-project notifications when one agent changes something that affects others
- **Domain skills** — specialist agent knowledge (e.g. "payment processing expert", "scheduling expert")

**You don't need a blueprint to start.** For single-project teams, all domain knowledge lives in the project's `.memory/`. Create a blueprint only when you have multiple projects that need shared knowledge.

---

## How it works

Each project repo gets three things wired up during setup:

1. **Memory** (`.memory/`) — a separate Git branch (`ai-memory`) that lives alongside your code. Contains the agent's persistent knowledge: a map of every module and class, a symbol index of every public function, session state, lessons learned, sacred behaviors, tech debt findings, and dependency versions. This is how the agent remembers across sessions.

2. **Rules, skills, and workflows** (`.agents/`) — Markdown files that tell the agent how to behave. Rules are always-on principles (security, code quality). Skills are specialist knowledge loaded on demand or step-by-step procedures with gates (session start, task completion, git flow). Workflows are multi-step missions triggered by the user (map the codebase, develop a feature, sync with the skeleton).

3. **Entry points** — each AI tool discovers the agent setup through its own mechanism. Claude Code reads `CLAUDE.md` and `.claude/skills/`. Antigravity reads `GEMINI.md` and `.agent/` (a symlink to `.agents/`). All point to the same source of truth.

---

## Roles

agentskel is role-based. You choose which agent roles to install on each project:

| Role | What it provides | Status |
|------|-----------------|--------|
| **dev** | 13 workflows (cartographer, develop-feature, sync-skeleton, and more). 5 standards (architecture, git, style, dependency, API). Claude Code skill stubs (auto-generated). | Ready |
| **devops** | Deployment, monitoring, incident response workflows. | Planned |

Core capabilities (memory, session management, git flow, security rules) are always installed regardless of role.

---

## Getting started

### Step 0 — Get agentskel on disk

Clone agentskel locally. Every project on the same machine shares a single clone.

```bash
git clone https://github.com/ahmadulhoq/agentskel.git
```

---

### Setting up a new project (tech lead only)

#### Step 1 — Set up agentic infrastructure

Open your project in Claude Code (or Antigravity), then run:

> *"Set up agentic development on this project with the dev role. The skeleton is at `../agentskel`."*

The agent asks a few questions (platform, app name, GitHub slug, default branch, lead engineer), then automatically wires up everything: memory files, rules, workflows, skills, `CLAUDE.md`, and `scripts/install-agent.sh`. It opens a PR for the team to review before merging.

**Run once per project.**

#### Step 2 — Map the codebase

> *"Map this codebase."*

The agent scans every module — indexing every class and function so it can find features and logic directly in future sessions. It also researches the tech stack to create `.memory/CONVENTIONS.md`, and flags tech debt, sacred behaviors, and dependency versions.

**This is a multi-session process for large codebases.** The agent checkpoints and resumes where it left off.

#### Step 3 — Start developing

The agent is ready. Just describe what you want:

> *"Fix the bug where login fails on network timeout."*
>
> *"Add a feature to show the user's recent activity."*
>
> *"Review this PR for architecture violations."*

Every session the agent reads its memory, checks for skeleton updates, and picks up where it left off.

---

### Joining a project that's already set up (any developer)

You do **not** need the agentskel repo.

#### Step 1 — Install the agent

After cloning the project, run:

```bash
./scripts/install-agent.sh
```

This script detects whether the project has AI memory, mounts it, and you're ready to go.

#### Step 2 — Start developing

Open the project in Claude Code (or Antigravity) and describe your task. The agent reads its memory, loads the rules and skills, and starts working.

---

## Keeping in sync

When agentskel is updated, project agents detect the version gap at session start. When found, run:

> *"Sync this project with the latest skeleton."*

The agent walks through every CHANGELOG entry since the last sync (Apply / Adapt / Skip), then opens a PR for review.

---

## Adding a blueprint (multi-project teams)

When you have 2+ projects that share domain knowledge:

1. Create a new repo for your blueprint.
2. Add `domain/`, `specs/`, `parity/`, `bus/`, and `skills/` directories as needed.
3. Set `Blueprint Path` in each project's `.memory/CONFIG.md` pointing to the local clone.
4. Agents will read domain knowledge on demand and write to it when domain knowledge changes.

The blueprint is maintained naturally by agents as a byproduct of work — not manually curated.

---

## What's in this repo

**Core (`core/`)** — Memory templates, rules, procedural skills, and entry point templates. Always installed.

**Roles (`roles/`)** — Opt-in agent roles. Each brings its own workflows, skills, standards, and prompts.

**Version tracking** — `VERSION` and `CHANGELOG.md` at the repo root.

---

## Current version

**v1.0** — see [CHANGELOG](CHANGELOG.md) for what changed.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT — see [LICENSE](LICENSE).
