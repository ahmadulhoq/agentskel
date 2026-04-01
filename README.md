# agentskel

> Persistent memory, shared standards, and structured workflows for AI coding agents.

AI agents forget everything between sessions. They re-scan your codebase, miss conventions, repeat past mistakes, and have no awareness of your architecture.

**agentskel** gives your agents memory that persists, rules they always follow, and workflows for complex tasks. Install it on any existing project — no fork, no migration, no application code changes.

---

## Quick start

### Install (one-time)

```bash
# Claude Code
/plugin install agentskel

# Gemini CLI
gemini extensions install https://github.com/ahmadulhoq/agentskel

# Codex / Cursor / Copilot / Windsurf — see docs/INSTALL.md
```

### Set up a project (tech lead, one-time)

Open your project and say:

> *"Set up agentskel on this project."*

The agent asks for project details, creates memory files, copies rules and workflows, and opens a PR. After merge, say *"Map this codebase"* to build the agent's memory.

### Join a project (any developer)

```bash
./scripts/install-agent.sh
```

Done. The agent reads its memory and picks up context automatically.

---

## What your agent gets

### Memory (`.memory/`)

A persistent knowledge base on a separate Git branch — never touches your application code.

| What it remembers | Files |
|---|---|
| **Codebase structure** | `MAP.md` (modules), `SYMBOLS.md` (classes/functions) |
| **Session state** | `RESUME.md` (what it was doing, what's next) |
| **Project identity** | `CONFIG.md`, `RULES.md`, `CONVENTIONS.md` |
| **Hard-won lessons** | `SACRED.md` (don't touch), `LESSONS.md` (past mistakes) |
| **Dependency health** | `VERSIONS.md`, `DEPENDENCY_ALERTS.md` |
| **Work tracking** | `CHANGELOG.md`, `TIME_LOG.md`, `TECH_DEBT.md` |

### Rules (`.agents/rules/`)

Always-on principles: planning before coding, verification before done, security non-negotiables, git discipline. Includes rationalization resistance — the agent can't talk itself out of following the rules.

### Skills (`.agents/skills/`)

Specialist knowledge loaded on demand:

| Skill | What it does |
|---|---|
| `session-start` | Reads memory, checks versions, surfaces alerts |
| `task-completion` | CHANGELOG, time log, memory commit — nothing gets skipped |
| `senior-developer` | Architecture decisions, code quality, SOLID principles |
| `code-reviewer` | PR review against standards and sacred behaviors |
| `test-engineer` | Test strategy, coverage, test writing |
| `subagent-dispatch` | Delegate tasks to fresh subagents with prompt templates |
| `skill-authoring` | Guide for creating new skills with quality gates |

### Workflows (`.agents/workflows/`)

15 structured workflows for common tasks:

| Task | Say this |
|---|---|
| Build a feature | *"Develop a feature for X"* |
| Fix something | *"Fix this bug"* or *"Fix tech debt DEBT-001"* |
| Emergency fix | *"Hotfix: production is broken"* |
| Cut a release | *"Cut a release"* |
| Audit dependencies | *"Check dependencies"* |
| Map the codebase | *"Map this codebase"* |

---

## Works with every AI tool

| Tool | How it discovers agentskel |
|---|---|
| Claude Code | Plugin + session-start hook |
| Cursor | Plugin + native rule |
| Copilot | `.github/copilot-instructions.md` |
| Windsurf | Native rule |
| Codex CLI | Reads `AGENTS.md` natively |
| Gemini / Antigravity | Extension + `GEMINI.md` |

All tools read the same rules, skills, and workflows from `.agents/`. One setup, every tool.

---

## Keeping in sync

agentskel is versioned. Your agent detects version gaps at session start:

> *"Sync this project with the latest skeleton."*

The agent walks through each change (Apply / Adapt / Skip) and opens a PR.

---

## Blueprints (optional)

For teams with multiple projects sharing business logic (e.g. Android + iOS + backend), create a **blueprint** — a shared knowledge repo with specs, feature parity tracking, and a Knowledge Bus for cross-project notifications. Projects connect via `Blueprint Path` in their CONFIG.md; agents pull specs and check for cross-platform action items at session start.

You don't need a blueprint to start. Create one when you have 2+ projects that need shared domain knowledge.

---

## Manual install (without plugin)

If you prefer not to use the plugin system:

```bash
git clone https://github.com/ahmadulhoq/agentskel.git
```

Then open your project and say: *"Run the setup-skeleton workflow. The skeleton is at `../agentskel`."*

---

## Current version

**v1.26** — see [CHANGELOG.md](CHANGELOG.md) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
