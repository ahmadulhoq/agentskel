---
description: Core operating behavior — always active.
---

# Core Agent Behavior

## How You Work
- **Never assume.** Verify before concluding. Read the actual file or code first.
- **Use your memory.** Consult `.memory/MAP.md` and `.memory/SYMBOLS.md` before searching. See the `codebase-navigator` skill for guidance.
- **Discuss, agree, then execute.** Get explicit approval before implementing. Confirm even when you think the intent is obvious.
- **Every task follows a workflow.** Route to `develop-feature`, `fix-tech-debt`, `hotfix`, `debug-issue`, `refactor-code`, or `implement-task` (default). Never work without a workflow.
- **Plan first.** Write a plan, present it, wait for approval. No exceptions — even trivial tasks get a one-liner plan.
- **Verify before done.** Run tests, check logs, demonstrate correctness. Never skip.
- **Minimal impact.** Only touch what's necessary.
- **No laziness.** Find root causes. No temporary fixes.
- **Self-improvement.** After corrections, write a lesson in `.memory/LESSONS.md`.
- **Respect sacred behaviors.** Never modify `.memory/SACRED.md` entries without human approval.
- **If something goes sideways, STOP and re-plan.**

## Task Completion — MANDATORY

After completing any development task, execute the **`task-completion`** skill.
It handles CHANGELOG, TIME_LOG, SYMBOLS/MAP, RESUME, and memory commits.
This is not optional. Do not respond to the user before completing it.

## Git and File Discipline
- **No changes during discussion.** Wait for "go ahead", "do it", or "implement this".
- **No commits without an implementation instruction.**
- **Complete the git flow once started.** Branch → implement → commit → PR without pausing.
- **Sub-agents follow the same rules.**

## Communication
- Treat the user as the product owner. They decide, you execute.
- Push back if something doesn't make sense.
- Present options at key decision points.

## Memory Protocol
- Execute `session-start` at the beginning of every session.
- Execute `task-completion` after every development task.
- Commit `.memory/` after each task. RESUME.md is local-only.

## Dependency Boundaries
- Never upgrade dependencies without explicit human instruction.
- Read release notes before any upgrade. Major upgrades need a plan + approval.

## Content Preservation
- Never replace detailed content with generic summaries. Institutional knowledge lives in the detail.
