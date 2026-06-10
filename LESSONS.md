# Agent Lessons Learned

<!-- The agent writes entries here after being corrected.
     It reads this file at session start to avoid repeating mistakes.
     Format: ## Lesson NNN — YYYY-MM-DD
     Include: Mistake, Pattern, Rule -->

## Lesson 007 — 2026-06-02
- **Mistake:** Added BL-001 to BACKLOG.md (multi-project Android skills deduplication via shared store + symlinks) without checking the CHANGELOG. The work had already shipped in v1.58.0 — "Shared external skills store (~/.agentskel/skills/) + gitignored symlinks + core/external-skills.yml manifest." The backlog entry was obsolete the moment it was written.
- **Pattern:** Treating in-conversation context as current when the session had been paused. Between the previous design discussion (v1.57.x era) and this turn, the date had advanced ~10 days and four releases shipped (v1.57.1, v1.57.2, v1.57.3, v1.58.0). Acted on the older discussion context without reconciling against current repo state.
- **Rule:** Before adding any item to BACKLOG.md or TECH_DEBT.md — especially when the item reflects a previously-discussed idea — grep CHANGELOG.md for related keywords (here: "external skills", "symlink", "shared store"). If the work already shipped, do not file the entry. More generally: after any session gap (date change, `/resume`, long pause), run `git log --oneline -20` and read recent CHANGELOG entries before acting on prior-conversation topics. The repo moves forward without you.

## Lesson 006 — 2026-05-17
- **Mistake:** Diagnosed the Stop hook loop and immediately implemented a fix (removed the hook entirely) without presenting a plan and waiting for user approval.
- **Pattern:** "This is clearly broken, I'll fix it fast" — urgent-seeming bugs trigger the impulse to skip planning.
- **Rule:** Urgency is not an exception to plan-first. Even for obvious bugs, state the diagnosis, propose the fix, wait for "go ahead." The user caught both the process violation AND that the fix was too blunt (removing enforcement entirely instead of replacing with a correct implementation).
- **Specific trigger:** Calling Edit or Write tools is the exact moment the gate must be checked. Before any Edit/Write call, verify in thinking: "Did the user say go-ahead/do-it/proceed/implement in the *current exchange*?" A prior approval from an earlier message does not carry forward to new implementation steps. Concerns, tradeoffs, or analysis shared during discussion are not approval.

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

## Lesson 008 — 2026-06-10
- **Mistake (observed by internal team across multiple downstream sessions):** Three recurring agent failure patterns — (1) shipping without considering existing architecture, silently working around patterns that look wrong; (2) treating "smaller commits" as one-shot guidance that didn't persist across the workflow; (3) implementing Jira tickets verbatim without reviewing existing implementation, enumerating edge cases, or flagging significant logic changes.
- **Pattern:** Agents default to "extract the work item and execute it" without the contextual checks a senior dev would do reflexively. Ticket text becomes a contract; existing code becomes a mystery box; user instructions become disposable.
- **Rule (v1.65.0):** Architecture Survey is a mandatory plan sub-step (with skip-if-trivial carve-out). Commit granularity instructions persist for the workflow's lifetime, not one commit. Ticket-driven workflows must read existing code, enumerate edge cases, and require separate confirmation for significant changes (>30 lines existing logic / public API / sacred). Codified in `develop-feature`, `implement-task`, `implement-from-ticket`, `git-flow`, `developer`, and `core-behavior` (propagated to all 10 inline-rule files).
