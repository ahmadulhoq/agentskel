---
activation: always
description: Core operating behavior for all agents in this repo.
---

# Core Agent Behavior

## How You Work
- **Discuss, agree, then execute.** Never start implementing while
  requirements are still being discussed. Complete the discussion,
  summarise the agreed changes, get explicit approval, then execute.
- **Plan first.** For any non-trivial task (3+ steps or architectural
  decisions), write a plan before coding. Check in before executing.
- **Verify before done.** Never mark a task complete without proving it
  works. Run tests, check logs, demonstrate correctness.
- **Minimal impact.** Changes should only touch what's necessary.
- **No laziness.** Find root causes. No temporary fixes. Senior
  developer standards.
- **Simplicity first.** Make every change as simple as possible.
- **Self-improvement.** After any correction, write a lesson in
  `.memory/LESSONS.md`. Review LESSONS.md at session start.
- **Respect sacred behaviors.** Read `.memory/SACRED.md` at session start.
  Never modify anything listed there without explicit human approval.
  If you discover a behavior that looks wrong but might be intentional,
  do NOT decide it is sacred on your own. Follow the Triage Protocol:
  classify by confidence, and escalate ambiguous cases to the user
  via NEEDS_REVIEW.md.
- **If something goes sideways, STOP and re-plan.** Don't keep pushing.

## Task Completion

After completing any development task, execute the **`task-completion`** skill.
It handles CHANGELOG, TIME_LOG, SYMBOLS/MAP, Knowledge Bus, RESUME, and memory commits.
This is mandatory — not optional.


## Git and File Discipline
- **No changes during discussion.** While the user is discussing, reviewing options, or pointing out issues — do not edit files, create files, or run any write operations. Wait for an explicit signal to proceed (e.g. "go ahead", "do it", "implement this", "yes").
- **No commits without an implementation instruction.** Never run `git commit` or `git push` unless the user has explicitly asked to implement or commit in the current message. Completing analysis or finishing edits does not grant commit permission.
- **Commits are part of implementation.** When the user asks to implement a change, committing the result is included — no separate commit approval is needed once implementation has been requested.
- **Complete the git flow once started.** When implementation has been authorised, execute the full git workflow end-to-end (branch → implement → commit → PR) without pausing for additional approval. Do not stop after making file changes and wait to be asked to commit.
- **Sub-agents follow the same rules.** Do not instruct a spawned sub-agent to commit or push unless the user has authorised implementation in the current session.

## How You Communicate
- Treat the user as the product owner. They make decisions, you execute.
- Don't overwhelm with jargon. Translate technical concepts.
- Push back if something doesn't make sense or is heading down a bad path.
- Be honest about limitations. Adjust expectations rather than disappoint.
- At key decision points, present options rather than picking one silently.
- Build in stages the user can see and react to.

## How You Handle Errors
- Failed tasks must include a clear, human-readable error report.
- Error messages should suggest remediation paths or diagnostic steps.
- Log actions with appropriate severity (INFO, WARNING, ERROR).
- All decisions must be traceable to logs, data, or configuration.

## Memory Protocol

At the start of every session, execute the **`session-start`** skill. It handles
memory detection, file reading, version checks, and git state verification.

After completing any development task, execute the **`task-completion`** skill. It
handles CHANGELOG, TIME_LOG, SYMBOLS/MAP, RESUME, and memory commits.

Key principles (always active):
- Update RESUME.md after each completed sub-task and before ending any session.
- Never delete RESUME.md. Set Status to IDLE when tasks are complete.
- After each checkpoint, commit `.memory/` changes to the ai-memory branch.
  RESUME.md is excluded from commits (it is local-only).
- At session end, commit and push to origin.

## Skeleton Contribution
- When modifying a workflow, skill, or rule in `.agents/`, classify the change:
  - **Project-specific** (tool names, platform APIs, project conventions) →
    update only this project's `.agents/` files.
  - **Universal** (logic or policy that applies to all projects) → also update
    the corresponding skeleton template (in agentskel), bump `VERSION`,
    and add an entry to `CHANGELOG.md`.
- **Every change to any skeleton file** (template, workflow, standard, rule, skill)
  — whether made by a project agent or directly — **must**:
  1. Bump `VERSION` (MINOR for additions, MAJOR for breaking changes)
  2. Add an entry to `CHANGELOG.md`
  3. Update the `## Current version` line in the skeleton's `README.md` to match the new VERSION
  4. If the change affects structure, architecture, or install/sync paths —
     update `MASTER_PLAN.md` and its `Corresponds to:` version marker
  No exceptions. This is how repos know they are out of sync.
- When a change affects **how the system works or how developers set up/use it**,
  update the skeleton's `README.md`.

## Blueprint Contribution (if configured)
- When your work touches shared domain knowledge (business logic, API contracts,
  cross-platform behaviour), update the relevant files in the blueprint repo.
- The blueprint is optional — only contribute if `Blueprint Path` is set in
  `.memory/CONFIG.md` and the change affects cross-project domain knowledge.
