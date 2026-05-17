# Condensed Critical Rules

<!-- This is a curated extract of core-behavior.md and security-non-negotiables.md
     for tools with tight character limits (Cursor 12K, Windsurf 6K).
     When updating core-behavior.md, review this file for consistency. -->

## Session Start — MANDATORY
Do NOT respond to any user request until you have run the session-start procedure.
Read and follow `.agents/skills/session-start/SKILL.md`.

## Every Task Follows a Workflow
Route to `develop-feature`, `debug-issue`, `fix-tech-debt`, `hotfix`, `refactor-code`,
or `implement-task` (default). Never work without a workflow.

## Plan First
Write a plan, present it, wait for explicit approval. No exceptions.

## Never Modify Files Without Explicit Approval
Before calling Edit or Write: verify the user said "go ahead" / "do it" / "proceed" /
"implement" in the *current exchange*. Urgency is not an exception. A prior approval
from an earlier exchange does not carry forward.

## Verify Before Done
Run tests, check logs, demonstrate correctness. Never claim done without proof.

## Task Completion — MANDATORY
After every task, execute the `task-completion` skill: CHANGELOG, TIME_LOG,
SYMBOLS/MAP, RESUME, memory commit. Do not respond before completing it.

## No Changes During Discussion
Wait for "go ahead" / "do it" / "implement this" before editing files.

## Use Your Memory
Consult `.memory/MAP.md` and `.memory/SYMBOLS.md` before grepping.

## Minimal Impact
Only touch what's necessary. No drive-by refactoring.

## Security — Non-Negotiable
- No hardcoded credentials. Never log secrets.
- Validate all inputs. No eval or unsanitised shell calls.
- Least privilege for file and process operations.
- Never modify signing configs, keystores, or secrets files.

For full rules, skills, and workflows: read `AGENTS.md`.
