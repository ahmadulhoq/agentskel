# agentskel

> The `.github/` folder for your AI agents.

---

You have five developers. Each one uses a different AI tool — Claude Code, Cursor, Copilot, Windsurf. Each agent behaves completely differently. No shared standards. No shared knowledge. No shared memory of what the team has already decided.

One agent proposes an architecture your team explicitly rejected last month. Another doesn't know about the payment module's edge cases. A third re-scans 40 files every session to figure out what the first two already mapped.

**agentskel is team infrastructure for AI agents.** A shared, versioned layer — installed once, read by every tool — that gives every agent on your team the same standards, the same codebase knowledge, and the same methodology. Like `.github/` for CI workflows, but for agent behavior.

No forks. No migrations. No changes to your application code.

---

## What changes

**Before agentskel:**
> Developer A's Claude agent and Developer B's Cursor agent propose conflicting approaches to the same problem. Neither knows about the architectural decision made three weeks ago. Both re-scan the codebase from scratch every session.

**After agentskel:**
> Every agent — regardless of tool or developer — reads the same rules, knows your codebase (every module, class, and function), follows the same workflows, and inherits the same hard-won lessons. A decision made once is known by all agents, forever.

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

The agent asks for your project details, creates shared knowledge files, installs rules and workflows, and opens a PR. After merge, say *"Map this codebase"* — the agent reads every file and builds a shared knowledge base for the whole team.

### 3. Join a project (any developer, once)

```bash
./scripts/install-agent.sh
```

Done. Your agent reads the team's shared knowledge and behaves consistently from the first session.

---

## What it enforces

### Shared standards (`.agents/rules/`)

Always-on principles every agent follows, regardless of tool: plan before coding, verify before shipping, no commits without a branch, security non-negotiables. Includes rationalization resistance — the agent can't talk itself out of following the rules.

### Shared methodology (`.agents/skills/`)

Specialist behavior loaded when relevant:

| Skill | What it enforces |
|---|---|
| `brainstorm-feature` | No code until the spec is agreed — 2–3 targeted questions first |
| `test-driven-development` | RED → GREEN → REFACTOR — no production code without a failing test |
| `systematic-debugger` | Root cause confirmed before any fix — no guess-and-check |
| `using-git-worktrees` | Isolated workspaces for long runs — branch stays clean |
| `developer` | Architecture decisions, SOLID principles, code quality |
| `code-reviewer` | PRs reviewed against your standards and sacred behaviors |
| `test-engineer` | Test strategy, coverage, test writing |
| `session-start` | Reads shared knowledge, surfaces alerts — before touching anything |
| `task-completion` | CHANGELOG, time log, memory commit — every task, every agent |

### Shared workflows (`.agents/workflows/`)

17 structured workflows triggered by plain English — same workflow, same steps, every agent:

| Say this | Workflow |
|---|---|
| *"Think through this feature with me"* | `brainstorm-feature` — spec-first |
| *"Develop a feature for X"* | `develop-feature` — plan → branch → TDD → PR |
| *"Fix this bug"* | `debug-issue` — reproduce → failing test → root cause → fix |
| *"Hotfix: production is down"* | `hotfix` — expedited flow |
| *"Cut a release"* | `cut-release` |
| *"Map this codebase"* | `cartographer` — builds shared knowledge base |

### Shared codebase knowledge (`.memory/`)

A knowledge base on a separate Git branch — versioned, shared across the team, never touching your application code.

| What every agent knows | File |
|---|---|
| Every module, entry point, and critical flow | `MAP.md` |
| Every class and function, where it lives | `SYMBOLS.md` |
| Your conventions and project rules | `RULES.md`, `CONVENTIONS.md` |
| Decisions that must never be reversed | `SACRED.md` |
| Past mistakes — so no agent repeats them | `LESSONS.md` |
| Dependency health | `VERSIONS.md`, `DEPENDENCY_ALERTS.md` |
| Work history | `CHANGELOG.md`, `TIME_LOG.md`, `TECH_DEBT.md` |
| What was in progress | `RESUME.md` |

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

A system prompt is per-developer, per-tool, and resets every session.

agentskel is shared across the team, works across every tool, and persists indefinitely. When your tech lead encodes an architectural decision, every agent on every tool knows about it — immediately, permanently. When one agent learns a lesson from a production bug, no other agent ever makes the same mistake.

A system prompt stays flat. agentskel compounds.

---

## For larger teams: Blueprints

If you have multiple projects sharing business logic (e.g. iOS + Android + API), create a **Blueprint** — a shared knowledge repo with domain specs, feature parity tracking, and a Knowledge Bus for cross-project coordination.

When a backend agent changes an API contract, it posts a bus entry. iOS and Android agents read it at session start and know exactly what action to take. No Slack ping. No meeting. No drift.

> You don't need a Blueprint to start. Create one when two or more of your projects need to stay in sync.

---

## Staying up to date

agentskel is versioned. Your agent detects gaps at session start and says so. To sync:

> *"Sync this project with the latest skeleton."*

The agent walks through each change — Apply, Adapt, or Skip — and opens a PR. You stay in control.

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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Skills and workflows are plain Markdown — no code required.

## License

MIT — see [LICENSE](LICENSE).
