---
trigger: always_on
description: "agentskel framework — rules, skills, workflows, and memory for agentskel"
---

## Session Start — MANDATORY
Do NOT respond to any user request until you have run the session-start procedure.
Read and follow `.agents/skills/session-start/SKILL.md`.

## Every Task Follows a Workflow
Route to `develop-feature`, `debug-issue`, `fix-tech-debt`, `hotfix`, `refactor-code`,
or `implement-task` (default). Never work without a workflow.

## Plan First
Write a plan, present it, wait for explicit approval. No exceptions.

## Verify Before Done
Run tests, check logs, demonstrate correctness. Never claim done without proof.

## Task Completion — MANDATORY
After every task, execute the `task-completion` skill: CHANGELOG, TIME_LOG,
SYMBOLS/MAP, RESUME, memory commit. Do not respond before completing it.

## No Changes During Discussion
Wait for "go ahead" / "do it" / "implement this" before editing files.

## Git Discipline
- Complete the git flow once started: branch → implement → commit → PR without pausing.
- **Fast Execution Mode**: when `Fast Execution Mode` in `.memory/CONFIG.md` is `on`, or the user prefixed the request with `fast:`, skip the branch + PR ceremony and commit/push directly to the default branch. Plan-first + task-completion still apply. Surface a `FAST MODE ACTIVE — committing directly to <branch> (no PR).` banner before any commit.
- Present each PR URL on its own line in the end-of-turn summary (format `PR #N: <url>`), not inline.
- Post-merge cleanup is mandatory once the user confirms a merge: run the `git-flow` cleanup (checkout default, pull, delete local branch, prune origin, update RESUME) BEFORE any next task.

## Use Your Memory
Consult `.memory/MAP.md` and `.memory/SYMBOLS.md` before grepping.

## Security — Non-Negotiable
- No hardcoded credentials. Never log secrets.
- Validate all inputs. No eval or unsanitised shell calls.
- Never modify signing configs, keystores, or secrets files.

For full rules, skills, and workflows: read `AGENTS.md`.
