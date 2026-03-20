# agentskel — Claude Code Instructions

Read and follow all rules in `.agents/rules/` before starting any task.

This repo is the agentskel framework — the generic skeleton for agentic development.
It contains templates, rules, workflows, skills, and standards that get installed
on downstream projects. There is no application code here.

Key files:
- `MASTER_PLAN.md` — ADR: full system design (local only, not in repo)
- `README.md` — public-facing documentation for users adopting agentskel
- `agent-hq/VERSION` + `agent-hq/CHANGELOG.md` — version tracking (bump on every change)
- `core/` — memory templates, rules, procedural skills, entry point templates
- `roles/dev/` — dev role: workflows, standards, skills, prompts, claude-skills
