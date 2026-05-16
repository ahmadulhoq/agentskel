# agentskel

> Give your AI coding agents persistent memory and shared team standards.

---

AI coding assistants forget everything between sessions. They re-read your code every time, miss your team's conventions, and repeat the same mistakes. On a team, it gets worse — every developer's agent behaves differently.

**agentskel** fixes this. It gives every agent on your team a persistent memory of your codebase, a set of rules they always follow, and structured workflows for common tasks like building features, fixing bugs, and reviewing code. Install it once — no changes to your application code.

---

## Why you'd want this

| Without agentskel | With agentskel |
|---|---|
| Agent re-reads 40 files every session | Agent remembers your code between sessions |
| Agent doesn't know your team's conventions | Agent learns and enforces your team's standards |
| Each developer's agent behaves differently | Everyone's agent follows the same rules |
| Past mistakes get repeated | Agent remembers what went wrong and avoids it |
| Cross-platform apps drift out of sync | Shared business logic stays consistent across platforms |

---

## How it stores the memory

Your team's shared knowledge lives in a Git branch inside your repo. Plain markdown files, versioned alongside your code, shared via `git push`. No database, no API key, no vendor lock-in — just Git.

---

## Install (one-time, per developer)

```bash
# Claude Code
/plugin install agentskel

# Gemini CLI
gemini extensions install https://github.com/ahmadulhoq/agentskel

# Cursor / GitHub Copilot / Windsurf / Codex — see INSTALL.md
```

---

## Getting started

Open your project in your AI tool and say one of the following:

**Single project?**
> *"Set up agentskel on this project."*

**A folder with multiple projects inside (e.g. a backend folder + a mobile app folder)?**
> *"Set up agentskel as a workspace."*

**Multiple projects that share the same business logic and need to stay in sync?**
> *"Create a blueprint here."*

Not sure which fits? See [docs/INSTALL-MODES.md](docs/INSTALL-MODES.md).

---

## Connect to the tools your team already uses (optional)

After setup, connect your team's Jira, Confluence, and GitHub so the agent participates in your work processes:

**Capture the team roster:**
> *"Set up the team."*

**Enable ticket-based workflows (read tickets, update status, reassign to QA):**
> *"Set up Jira."*

**Enable publishing ADRs, postmortems, and specs to Confluence:**
> *"Set up Confluence."*

Each setup is independent — use any subset. Requires the Atlassian MCP connected in your AI tool. See [docs/ATLASSIAN-SETUP.md](docs/ATLASSIAN-SETUP.md) for connection details and [docs/TEAM-COORDINATION.md](docs/TEAM-COORDINATION.md) for how the three layers (memory, Jira, Confluence) work together.

---

## Joining an existing project

If your teammate already set up agentskel, clone the project and run:

```bash
./scripts/install-agent.sh
```

Your agent now has access to everything the team has learned.

---

## What you get

**A shared memory of your codebase.** The agent reads every file once, indexes every class and function, and remembers how modules connect. Next session, it doesn't need to re-read.

**Rules every agent follows.** Security guardrails, coding conventions, planning before coding, verifying before shipping. The same rules apply whether you use Claude Code, Cursor, Copilot, or Gemini.

**Workflows for common tasks.** Plain-English commands like:

- *"Develop a feature for X"* → plans, branches, writes tests, implements, opens PR
- *"Fix this bug"* → reproduces, writes a failing test, finds root cause, fixes
- *"Map this codebase"* → builds a full index the agent uses forever after
- *"Check dependencies"* → audits for outdated or risky packages

**Cross-platform coordination (optional).** If your team has a backend and a mobile app that share business logic, agentskel keeps them in sync automatically. When the backend changes an API contract, the mobile agent sees it at next session start.

---

## Works with every major AI coding tool

Claude Code · Cursor · GitHub Copilot · Windsurf · Codex CLI · Gemini / Antigravity

One setup, every tool. Your teammates don't all have to use the same AI.

---

## Why not just use a system prompt?

A system prompt is per-developer, per-tool, and resets every session.

agentskel's knowledge lives in Git — shared across the team, works across every tool, and persists indefinitely. When your tech lead documents an architectural decision, every agent on every tool knows about it immediately. When one agent learns from a production bug, no agent ever makes the same mistake again. A system prompt stays flat. agentskel compounds.

---

## Keeping it up to date

agentskel gets better over time. Your agent detects when a new version is available:

> *"Sync this project with the latest skeleton."*

The agent walks through the changes, picks the ones that apply, and opens a PR.

---

## Manual install (without the plugin)

```bash
git clone https://github.com/ahmadulhoq/agentskel.git
```

Then in your project, say: *"Run the setup-skeleton workflow. The skeleton is at `../agentskel`."*

---

## Current version

**v1.55.1** — see [CHANGELOG.md](CHANGELOG.md) for what's new.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Skills and workflows are plain Markdown — no code required.

## License

MIT — see [LICENSE](LICENSE).
