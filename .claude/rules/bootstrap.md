---
description: Session bootstrap — mandatory procedures before any work.
---

# Session Bootstrap

## Session Start — MANDATORY
Do NOT respond to any user request until you have run the session-start procedure.
Read and follow every step in `.agents/skills/session-start/SKILL.md`.
This loads your memory of the codebase. Without it you will re-scan files unnecessarily,
miss known bugs, repeat past mistakes, and skip required post-task steps.

## Skill and Workflow Discovery
- Read `AGENTS.md` for the full skill/workflow catalog and memory references.
- Skills are also discoverable via `.claude/skills/` stubs.
- When a skill or workflow name is mentioned, execute it as a Claude Code skill.
