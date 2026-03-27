# agentskel

> Persistent memory, shared standards, and structured workflows for AI coding agents — installed on any existing project.

AI coding agents (Claude Code, Antigravity, Cursor, Copilot) are powerful but stateless. They forget everything between sessions, make inconsistent decisions across files, and have no awareness of your codebase's architecture, conventions, or history.

**agentskel** fixes this. It gives every project:

- **Memory that persists** — the agent maps your codebase once and remembers it across sessions
- **Rules it always follows** — security, code quality, architecture standards
- **Skills it can invoke** — specialist knowledge and step-by-step procedures
- **Workflows for complex tasks** — develop features, review code, manage dependencies, cut releases

Install it on your existing projects. No fork, no migration, no application code changes.

---

## How it works

agentskel sets up three things on your project:

### 1. Memory (`.memory/`)

A separate Git branch (`ai-memory`) mounted as a worktree. Contains the agent's persistent knowledge:

| File | Purpose |
|------|---------|
| `MAP.md` | Module registry — every module, its responsibility, key entry points |
| `SYMBOLS.md` | Symbol index — every public class and function with file locations |
| `RESUME.md` | Session state — what the agent was doing, what's next |
| `RULES.md` | Operating rules — how the agent behaves in this project |
| `CONFIG.md` | Project identity — platform, GitHub slug, skeleton version |
| `CONVENTIONS.md` | Observed patterns — naming, architecture, library usage |
| `SACRED.md` | Protected behaviors — code that looks wrong but exists for a reason |
| `LESSONS.md` | Past corrections — mistakes the agent must not repeat |
| `TECH_DEBT.md` | Findings — anti-patterns, bugs, missing tests, dead code |
| `VERSIONS.md` | Dependency tracker — current versions, latest known, release notes |
| `CHANGELOG.md` | Agent changelog — every change with description and reasoning |
| `TIME_LOG.md` | ROI tracking — estimated human hours vs agent duration |

Memory lives on its own branch. It never touches your application code or requires code review.

### 2. Rules, skills, and workflows (`.agents/`)

Markdown files that define agent behavior:

- **Rules** — always-on principles the agent follows on every task (security, code quality, git discipline)
- **Skills** — specialist knowledge loaded on demand. Some are procedural (session start, task completion, git flow). Others are domain expertise (senior developer, code reviewer, test engineer)
- **Workflows** — multi-step missions triggered by the user. Each has clear inputs, gates, and outputs
- **Standards** — architecture, style guide, git workflow, dependency management, API contracts

### 3. Entry points

Each AI tool discovers the setup through its own mechanism:

| Tool | Entry point | Discovery |
|------|------------|-----------|
| Claude Code | `CLAUDE.md` | Reads memory files, then `.claude/skills/` for skill/workflow stubs |
| Antigravity | `GEMINI.md` | Reads `.agent/` (symlink to `.agents/`) |

All tools read the same rules, skills, and workflows from `.agents/`.

---

## What's included

### Core (always installed)

| Component | Contents |
|-----------|----------|
| Memory templates | 15 files — CONFIG, RULES, MAP, SYMBOLS, RESUME, CONVENTIONS, SACRED, LESSONS, TECH_DEBT, NEEDS_REVIEW, VERSIONS, CHANGELOG, TIME_LOG, DEPENDENCY_ALERTS, DEPENDENCY_HISTORY |
| Rules | `core-behavior.md` — planning, verification, communication, memory protocol |
| | `security-non-negotiables.md` — credentials, input validation, least privilege |
| Procedural skills | `session-start` — memory detection, file reading, version checks, alerts |
| | `task-completion` — changelog, time log, symbols/map, resume, memory commit |
| | `git-flow` — branch naming, commit format, PR rules |
| Entry points | `CLAUDE.md.template`, `GEMINI.md.template`, `.claudeignore` |

### Dev role (opt-in)

| Component | Contents |
|-----------|----------|
| Workflows (14) | `cartographer` — map modules, classes, functions into memory |
| | `develop-feature` — branch, implement, test, commit, PR |
| | `fix-tech-debt` — pick a debt item, fix it, update registry |
| | `hotfix` — emergency fix with expedited flow |
| | `cut-release` — version bump, changelog, dependency snapshot |
| | `check-dependencies` — scan for outdated/vulnerable dependencies |
| | `sync-versions` — keep VERSIONS.md in sync with actual version files |
| | `update-conventions` — refresh CONVENTIONS.md from official sources |
| | `janitor` — monthly cleanup of stale memory, dead code, tech debt |
| | `setup-skeleton` — one-time install of agentskel on a new project |
| | `sync-skeleton` — update project when agentskel has new changes |
| | `check-skeleton` — detect version gap between project and skeleton |
| | `create-blueprint` — set up a shared domain knowledge repo for multi-project teams |
| | `parity-check` — cross-platform feature consistency audit |
| Domain skills (5) | `senior-developer` — architecture decisions, code quality, refactoring |
| | `code-reviewer` — PR review against standards and sacred behaviors |
| | `test-engineer` — test strategy, coverage analysis, test writing |
| | `task-planner` — break down features into implementable tasks |
| | `domain-expert` — project-specific business logic expertise |
| Standards (7) | Architecture, Style Guide, Git Workflow, Dependency Management, API Contracts |
| | Android Architecture — Compose/UDF, Hilt DI, Navigation, module graph, data layer |
| | iOS Architecture — SwiftUI, NavigationStack, Swift Concurrency, SPM modules, data layer |

Standards and skills support multiple platforms via `<!-- PLATFORM: X -->` markers. During setup, irrelevant platform sections are trimmed so each project gets clean, focused copies.

---

## Getting started

### Prerequisites

- An existing Git repository
- [Claude Code](https://claude.ai/download) or Antigravity installed
- agentskel cloned locally:

```bash
git clone https://github.com/ahmadulhoq/agentskel.git
```

You only need one clone. Every project on the same machine shares it.

### Setting up a project (tech lead, one-time)

Open your project repo in Claude Code (or Antigravity) and say:

> *"Run the setup-skeleton workflow. The skeleton is at `../agentskel`."*

The agent will:

1. **Ask** for project details — platform, app name, GitHub slug, default branch, lead engineer handle
2. **Create** the `ai-memory` branch and mount it at `.memory/`
3. **Populate** all 15 memory files with your project's identity
4. **Copy** rules, workflows, skills, and standards into `.agents/`, trimmed to your platform
5. **Generate** Claude Code skill stubs in `.claude/skills/`
6. **Create** `CLAUDE.md`, `GEMINI.md`, `.claudeignore`, `CODEOWNERS`, and `scripts/install-agent.sh`
7. **Open a PR** for the team to review before merging

After the PR is merged, run the **cartographer** workflow to build the agent's memory of your codebase:

> *"Map this codebase."*

This scans every module, indexes classes and functions, and flags tech debt. For large codebases this takes multiple sessions — the agent checkpoints and resumes automatically.

### Joining a project (any developer)

After cloning a project that already has agentskel set up:

```bash
./scripts/install-agent.sh
```

This mounts the AI memory. Open the project in Claude Code or Antigravity and start working — the agent reads its memory and picks up context automatically.

---

## Keeping in sync

agentskel is versioned. Each project tracks which version it was set up with (in `.memory/CONFIG.md`). When agentskel is updated:

1. The agent detects the version gap at session start
2. Run: *"Sync this project with the latest skeleton."*
3. The agent walks through each CHANGELOG entry since last sync (Apply / Adapt / Skip)
4. Opens a PR for the team to review

---

## Two components

### Skeleton (this repo — always required)

agentskel is the skeleton. It contains rules, workflows, skills, standards, and memory templates. No business logic, no org-specific content, no product knowledge.

### Blueprint (optional — for multi-project teams)

When multiple projects share the same business domain (e.g. Android app, iOS app, and backend for the same product), you create a **blueprint** — a separate repo of shared domain knowledge.

A blueprint contains:

| Directory | Purpose |
|-----------|---------|
| `specs/` | Business logic specs, API contracts, edge case documentation |
| `parity/` | Feature parity matrix — which platform implements what |
| `bus/` | Knowledge Bus — cross-project notifications when one agent changes shared logic |
| `skills/` | Domain-specific agent skills shared across projects |
| `CONFIG.md` | Blueprint identity — name, platforms, connected projects |

A blueprint has **no ai-memory branch** — it is a pure knowledge hub. Project-specific agents manage blueprint content by reading and writing to it via `Blueprint Path` in their own `.memory/CONFIG.md`. The blueprint includes a lightweight `.agents/` as a safety net if someone opens it directly.

**You don't need a blueprint to start.** For single-project teams, all domain knowledge lives in `.memory/`. Create a blueprint when you have 2+ projects that need shared knowledge.

---

## Repo structure

```
agentskel/
├── core/                          # Always installed
│   ├── memory/                    # Memory file templates (15 files)
│   ├── rules/                     # Core rules (always-on)
│   │   ├── core-behavior.md
│   │   └── security-non-negotiables.md
│   ├── skills/                    # Procedural skills
│   │   ├── session-start/
│   │   ├── task-completion/
│   │   └── git-flow/
│   ├── CLAUDE.md.template
│   ├── GEMINI.md.template
│   └── .claudeignore
├── roles/
│   └── dev/                       # Dev role (opt-in)
│       ├── workflows/             # 15 workflow files
│       ├── skills/                # 5 domain skills
│       ├── standards/             # 7 standard documents
│       └── prompts/               # Mission start prompts
├── VERSION                        # Current skeleton version
└── CHANGELOG.md                   # What changed in each version
```

---

## Current version

**v1.13** — see [CHANGELOG.md](CHANGELOG.md) for details.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
