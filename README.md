# agentskel

> Structured knowledge and enforced methodology for AI coding agents —
> installed on any project, shared across your team.

---

AI coding agents are stateless. Every session they re-scan your codebase,
forget your conventions, repeat past mistakes, and have no awareness of
decisions your team made last month. On a team, it's worse — every developer's
agent behaves differently, proposes conflicting approaches, and has no shared
understanding of your architecture.

**agentskel** fixes this. It gives every agent on your team persistent
knowledge of your codebase, rules they always follow, and structured workflows
for complex tasks. Install it once — no fork, no migration, no changes to
your application code.

---

## Why this exists

| Problem | What happens without agentskel |
|---------|-------------------------------|
| **Session amnesia** | Agent re-scans 40 files every session, asks questions already answered |
| **Codebase scale** | Large codebases don't fit in a context window — agents guess |
| **No institutional knowledge** | Agent doesn't know the edge cases, the why, or the decisions |
| **Standards drift** | Five developers + five AI tools = five agents behaving differently |
| **Cross-platform drift** | iOS and Android agents diverge silently on shared business logic |
| **Repeated mistakes** | No agent learns from what went wrong last week |

---

## How the knowledge is stored

agentskel uses an orphaned Git branch (`ai-memory`) mounted as a `.memory/`
worktree. Plain markdown files, versioned alongside your code, shared across
the team via `git push`. No proprietary database, no API key, no vendor
lock-in — just Git.

---

## Quick start

### Install (one-time)

```bash
# Claude Code
/plugin install agentskel

# Gemini CLI
gemini extensions install https://github.com/ahmadulhoq/agentskel

# Codex / Cursor / Copilot / Windsurf — see INSTALL.md
```

### Set up a project (tech lead, once)

Open your project and say:

> *"Set up agentskel on this project."*

The agent asks for project details, creates memory files, copies rules and
workflows, and opens a PR. After merge, say *"Map this codebase"* — the agent
reads every file and builds a shared knowledge base for the whole team.

### Join a project (any developer)

```bash
./scripts/install-agent.sh
```

Done. Your agent reads the team's shared knowledge and picks up context
automatically.

---

## What your agent gets

### Memory (`.memory/`)

A persistent knowledge base on a separate Git branch — never touches your
application code.

| What it remembers | Files |
|---|---|
| **Codebase structure** | `MAP.md` (modules), `SYMBOLS.md` (every class and function) |
| **Session state** | `RESUME.md` (what it was doing, what's next) |
| **Project identity** | `CONFIG.md`, `RULES.md`, `CONVENTIONS.md` |
| **Hard-won lessons** | `SACRED.md` (don't touch), `LESSONS.md` (past mistakes) |
| **Dependency health** | `VERSIONS.md`, `DEPENDENCY_ALERTS.md` |
| **Work tracking** | `CHANGELOG.md`, `TIME_LOG.md`, `TECH_DEBT.md` |

### Rules (`.agents/rules/`)

Always-on principles every agent follows, regardless of tool: planning before
coding, verification before shipping, security non-negotiables, git discipline.
Includes rationalization resistance — the agent can't talk itself out of
following the rules.

### Skills (`.agents/skills/`)

Specialist behavior loaded when relevant:

| Skill | What it does |
|---|---|
| `session-start` | Reads memory, checks versions, surfaces alerts |
| `task-completion` | CHANGELOG, time log, memory commit — nothing gets skipped |
| `brainstorm-feature` | Asks targeted questions — no code until the spec is agreed |
| `test-driven-development` | RED → GREEN → REFACTOR — failing test before production code |
| `systematic-debugger` | Root cause confirmed before any fix — stops guess-and-check |
| `developer` | Architecture decisions, code quality, SOLID principles |
| `code-reviewer` | PR review against your standards and sacred behaviors |
| `test-engineer` | Test strategy, coverage analysis, test writing |
| `using-git-worktrees` | Isolated workspaces for long runs — keeps your branch clean |
| `subagent-dispatch` | Parallelize plan steps across fresh subagents |
| `codebase-navigator` | Traces flows, finds symbols — no re-scanning |

### Workflows (`.agents/workflows/`)

18 structured workflows triggered by plain English:

| Say this | Workflow |
|---|---|
| *"Think through this feature with me"* | `brainstorm-feature` — spec-first |
| *"Develop a feature for X"* | `develop-feature` — plan → branch → TDD → PR |
| *"Fix this bug"* | `debug-issue` — reproduce → failing test → root cause → fix |
| *"Fix tech debt DEBT-001"* | `fix-tech-debt` |
| *"Hotfix: production is down"* | `hotfix` — expedited flow |
| *"Cut a release"* | `cut-release` |
| *"Check dependencies"* | `check-dependencies` |
| *"Map this codebase"* | `cartographer` — builds MAP.md and SYMBOLS.md |

---

## Works with every AI tool

| Tool | How it discovers agentskel |
|---|---|
| Claude Code | Plugin + session-start hook |
| Cursor | Plugin + native rule |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Windsurf | Native rule |
| Codex CLI | Reads `AGENTS.md` natively |
| Gemini / Antigravity | Extension + `GEMINI.md` |

All tools read the same rules, skills, and workflows from `.agents/`.
One setup, every tool.

---

## Why not just use a system prompt?

A system prompt is per-developer, per-tool, and resets every session.

agentskel's knowledge lives in Git — shared across the team, works across
every tool, and persists indefinitely. When your tech lead encodes an
architectural decision, every agent on every tool knows about it immediately.
When one agent learns from a production bug, no agent ever makes the same
mistake again. A system prompt stays flat. agentskel compounds.

---

## Keeping in sync

agentskel is versioned. Your agent detects version gaps at session start:

> *"Sync this project with the latest skeleton."*

The agent walks through each change (Apply / Adapt / Skip) and opens a PR.

---

## Blueprints (optional)

For teams with multiple projects sharing business logic (iOS + Android +
backend), create a **Blueprint** — a shared knowledge repo with domain specs,
feature parity tracking, and a Knowledge Bus for cross-project notifications.
When a backend agent changes an API contract, iOS and Android agents know
at next session start. No Slack ping required.

You don't need a Blueprint to start. Create one when 2+ projects need shared
domain knowledge.

---

## Manual install (without plugin)

```bash
git clone https://github.com/ahmadulhoq/agentskel.git
```

Then open your project and say:
*"Run the setup-skeleton workflow. The skeleton is at `../agentskel`."*

---

## Current version

**v1.43** — see [CHANGELOG.md](CHANGELOG.md) for what's new.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Skills and workflows are plain
Markdown — no code required.

## License

MIT — see [LICENSE](LICENSE).
