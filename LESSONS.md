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

## Lesson 004 — 2026-04-12
- **Mistake:** Completed multiple skeleton changes without bumping VERSION. The rule existed in `core-behavior.md` but the executable checklist (`skeleton-contribution-checklist.md`) had no VERSION step — so it was silently skipped every task-completion run.
- **Pattern:** Rules in always-on files get forgotten under compaction. Checklists are the enforcement mechanism — if a rule isn't in the checklist, it won't be followed.
- **Rule:** After any skeleton change, VERSION bump is the first step of skeleton-contribution-checklist (now enforced). If you notice a version hasn't been bumped after a commit, bump it immediately and note the sequence error in CHANGELOG.

## Lesson 005 — 2026-05-09
- **Mistake:** Implemented BACKLOG.md feature after user said "ok backlog now" — without re-presenting the plan or getting explicit approval.
- **Pattern:** A topic redirect ("let's go back to X") after a prior gate ("want to proceed or adjust?") was misread as implementation approval. Long prior discussion made the intent feel obvious, so confirmation was skipped.
- **Rule:** A gate stays open until explicitly cleared with GO/proceed/implement. A topic redirect (coming back after doing something else) is NOT approval — re-surface the plan and wait. "Confirm even when you think the intent is obvious" means especially when it feels obvious.

## Lesson 003 — 2026-03-27
- **Mistake:** Launched 3 explore agents to scan the entire codebase for static analysis references, when MAP.md already listed which files use platform markers and SYMBOLS.md had exact paths for every skill, workflow, and standard.
- **Pattern:** Defaulting to broad codebase search instead of consulting cartographed memory first. The whole point of cartography is to avoid re-scanning.
- **Rule:** Always consult MAP.md and SYMBOLS.md first to locate relevant files and modules. Only fall back to codebase search if the memory is stale or the information isn't indexed. This is now codified in core-behavior.md as "Use your memory."
