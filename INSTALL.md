# Installing agentskel

While agentskel offers native plugins for Claude Code and Gemini CLI, it is fully compatible with any AI coding assistant that supports workspace rules, memory, or custom system prompts.

This guide explains how to install and use agentskel with **Cursor**, **GitHub Copilot**, **Windsurf**, and **Codex CLI**.

---

## 1. Prerequisites (Once per machine)

Since there isn't a native command-line "install" command for these tools yet, you will need a local copy of the agentskel repository to serve as the template source.

Clone the agentskel repository to a convenient location on your machine (e.g., alongside your other projects):

```bash
cd ~/Work/Projects # Or wherever you keep your code
git clone https://github.com/ahmadulhoq/agentskel.git
```

## 2. Setting Up a Project (Once per project)

To enable agentskel on an existing project, you need to run the `setup-skeleton` workflow. This tells your AI assistant to read the templates from your local agentskel clone and install them into your project.

1. Open your target project in your IDE (Cursor, VS Code with Copilot, or Windsurf) or terminal.
2. Open the AI Chat interface.
3. Prompt your AI assistant with the following instruction (replace `../agentskel` with the actual path if you cloned it elsewhere):

> *"Run the setup-skeleton workflow on this repository. The skeleton source is located at `../agentskel`."*

The AI assistant will then guide you through the setup process. It will ask for your platform, app name, and which tools you want to support (be sure to include `cursor`, `copilot`, `windsurf`, or `codex` when asked).

## 3. What Gets Installed?

Depending on the tools you selected during setup, agentskel will generate specific configuration files to bootstrap the agent into the shared system:

- **Universal:** `AGENTS.md` (The canonical entry point, used natively by Codex CLI and as a fallback by others).
- **Cursor:** Creates `.cursor/rules/agentskel.mdc` which tells Cursor's AI to always read `AGENTS.md`.
- **Copilot:** Creates `.github/copilot-instructions.md` which instructs GitHub Copilot to start sessions using `AGENTS.md`.
- **Windsurf:** Creates `.windsurf/rules/agentskel.md` as an always-on trigger to hook into the framework.

## 4. Onboarding Your Team

Once the Tech Lead has run `setup-skeleton` and merged the resulting PR into your default branch, other developers do **not** need to repeat this process.

Other developers simply pull the `main` branch and run the generated script to mount the AI memory:

```bash
./scripts/install-agent.sh
```

No further installation is needed—their native tool (Cursor, Copilot, Windsurf) will automatically detect the entry point files and hook into the shared team memory.
