# agentskel

> Give your AI coding agent a memory, a methodology, and a team.

---

Every time you start a new session, your AI agent starts from zero.

It re-scans your codebase. It forgets the conventions you established last week. It repeats the same mistakes. It has no idea what it was doing yesterday — or why.

**agentskel fixes this.** It gives your agent a persistent memory that survives between sessions, structured workflows for complex tasks, and a shared knowledge system so every developer on your team gets the same well-behaved agent.

Install it on any project. No forks. No migrations. No changes to your application code.

---

## What it looks like in practice

**Without agentskel:**
> You: "Add a payment retry flow."
> Agent: *re-reads 40 files, asks questions you've answered before, proposes an approach that breaks a convention it doesn't know about, forgets all of this tomorrow.*

**With agentskel:**
> You: "Add a payment retry flow."
> Agent: *reads its memory — knows your codebase, where every class and function lives, how modules connect, past mistakes, sacred behaviors — navigates straight to the right files, asks the right questions to nail the spec, implements with TDD, logs what it did — and picks up exactly here next session.*

---

## Quick start

### 1. Install (one-time per developer)

```bash
# Claude Code
/plugin install agentskel

# Gemini CLI
gemini extensions install https://github.com/ahmadulhoq/agentskel

# Cursor / Copilot / Windsurf / Codex — see INSTALL.md
```

### 2. Set up your project (tech lead, once)

Open your project and say:

> *"Set up agentskel on this project."*

The agent asks for your project details, creates memory files, installs rules and workflows, and opens a PR. After merge, say *"Map this codebase"* — the agent reads every file and builds its own knowledge base.

### 3. Join a project (any developer, once)

```bash
./scripts/install-agent.sh
```

Done. The agent reads the team's shared memory and gets to work.

---

## What your agent gets

### Memory that persists

Agent knowledge lives on a separate Git branch (`.memory/`). It never touches your application code. Every session starts informed, not blank.

| What it remembers | File |
|---|---|
| Your codebase structure | `MAP.md` — modules, entry points, critical flows |
| Every class and function | `SYMBOLS.md` — indexed, searchable |
| Where it left off | `RESUME.md` — task state, what's next |
| Your conventions | `RULES.md`, `CONVENTIONS.md` |
| What must never change | `SACRED.md` — behaviors the agent won't touch without asking |
| Past mistakes | `LESSONS.md` — so it doesn't repeat them |
| Dependency health | `VERSIONS.md`, `DEPENDENCY_ALERTS.md` |
| Work history | `CHANGELOG.md`, `TIME_LOG.md`, `TECH_DEBT.md` |

### Rules it always follows

Always-on principles loaded at every session: plan before coding, verify before shipping, git discipline, security non-negotiables. The rules include rationalization resistance — the agent can't talk itself out of following them.

### Skills loaded on demand

| Skill | What it does |
|---|---|
| `session-start` | Reads memory, surfaces alerts, checks versions — before touching anything |
| `task-completion` | CHANGELOG, time log, memory commit — every task, every time |
| `brainstorm-feature` | Asks targeted questions to nail the spec *before* any code is written |
| `developer` | Code quality, SOLID principles, architecture decisions |
| `code-reviewer` | Reviews PRs against your standards and sacred behaviors |
| `test-engineer` | Test strategy, coverage analysis, test writing |
| `test-driven-development` | Enforces RED → GREEN → REFACTOR — no production code without a failing test first |
| `systematic-debugger` | Root cause analysis before any fix — stops guess-and-check loops |
| `using-git-worktrees` | Isolated workspaces for long runs — keeps your branch clean |
| `subagent-dispatch` | Delegates tasks to fresh subagents with structured prompts |
| `codebase-navigator` | Traces flows, finds symbols, navigates without re-scanning |

### Workflows for complex tasks

17 structured workflows triggered by plain English:

| Say this | Workflow |
|---|---|
| *"Think through this feature with me"* | `brainstorm-feature` — spec-first, no code until it's right |
| *"Develop a feature for X"* | `develop-feature` — plan → branch → TDD → PR |
| *"Fix this bug"* | `debug-issue` — reproduce → failing test → root cause → fix |
| *"Fix tech debt DEBT-001"* | `fix-tech-debt` |
| *"Hotfix: production is down"* | `hotfix` — expedited flow |
| *"Cut a release"* | `cut-release` |
| *"Check dependencies"* | `check-dependencies` |
| *"Map this codebase"* | `cartographer` — builds MAP.md and SYMBOLS.md |

---

## Works with every AI tool

One setup. Every tool reads the same rules, skills, and workflows from `.agents/`.

| Tool | How it discovers agentskel |
|---|---|
| Claude Code | Plugin + session-start hook |
| Cursor | Plugin + native rule |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Windsurf | Native rule |
| Codex CLI | Reads `AGENTS.md` natively |
| Gemini / Antigravity | Extension + `GEMINI.md` |

---

## Why not just use a system prompt?

A system prompt resets every session. agentskel doesn't.

The difference: a system prompt tells the agent *how to behave*. agentskel tells it *what it already knows* — your architecture, your conventions, your past mistakes, what it was doing yesterday. That knowledge compounds over time. A system prompt stays flat.

---

## For teams: Blueprints

If you have multiple projects sharing business logic (e.g. iOS + Android + API), create a **Blueprint** — a shared knowledge repo with domain specs, feature parity tracking, and a Knowledge Bus for cross-project notifications.

When a backend agent changes an API contract, it posts a bus entry. iOS and Android agents read it at session start and know what action to take. No Slack ping required.

> You don't need a Blueprint to start. Create one when two or more of your projects need to stay in sync.

---

## Staying up to date

agentskel is versioned. Your agent detects gaps at session start and says so. To sync:

> *"Sync this project with the latest skeleton."*

The agent walks through each change — Apply, Adapt, or Skip — and opens a PR. You stay in control of what changes.

---

## Manual install (no plugin)

```bash
git clone https://github.com/ahmadulhoq/agentskel.git
```

Then in your project:

> *"Run the setup-skeleton workflow. The skeleton is at `../agentskel`."*

---

## Current version

**v1.30** — see [CHANGELOG.md](CHANGELOG.md) for what's new.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Good first issues are labeled — skills and workflows are plain Markdown, no code required.

## License

MIT — see [LICENSE](LICENSE).
