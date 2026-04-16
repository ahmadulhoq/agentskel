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

## Use Your Memory
Consult `.memory/MAP.md` and `.memory/SYMBOLS.md` before grepping.

## Security — Non-Negotiable
- No hardcoded credentials. Never log secrets.
- Validate all inputs. No eval or unsanitised shell calls.
- Never modify signing configs, keystores, or secrets files.

For full rules, skills, and workflows: read `AGENTS.md`.
