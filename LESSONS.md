# Agent Lessons Learned

<!-- The agent writes entries here after being corrected.
     It reads this file at session start to avoid repeating mistakes.
     Format: ## Lesson NNN — YYYY-MM-DD
     Include: Mistake, Pattern, Rule -->

## Lesson 001 — 2026-03-25
- **Mistake:** Skipped TIME_LOG.md entry after completing a development task (spec drift fixes, v1.7).
- **Pattern:** Rushing through the task-completion checklist and treating TIME_LOG as optional.
- **Rule:** TIME_LOG Step 3 is mandatory for all development tasks — no exceptions. Run the full task-completion checklist after every task, every step, every time.

## Lesson 002 — 2026-03-26
- **Mistake:** Assumed skills were not being discovered by Claude Code without verifying. Reported 5 "orphaned skills" as gaps when they were all properly registered via `.claude/skills/` stubs with description-based auto-matching.
- **Pattern:** Jumping to conclusions about what's missing without reading the actual mechanism first. Assessed the `.agents/` directory but didn't check `.claude/skills/`.
- **Rule:** Never assume something is missing or broken. Verify by reading the actual files, mechanisms, and code before reporting a gap. This is now codified in core-behavior.md as "Never assume."

## Lesson 003 — 2026-03-27
- **Mistake:** Launched 3 explore agents to scan the entire codebase for static analysis references, when MAP.md already listed which files use platform markers and SYMBOLS.md had exact paths for every skill, workflow, and standard.
- **Pattern:** Defaulting to broad codebase search instead of consulting cartographed memory first. The whole point of cartography is to avoid re-scanning.
- **Rule:** Always consult MAP.md and SYMBOLS.md first to locate relevant files and modules. Only fall back to codebase search if the memory is stale or the information isn't indexed. This is now codified in core-behavior.md as "Use your memory."
