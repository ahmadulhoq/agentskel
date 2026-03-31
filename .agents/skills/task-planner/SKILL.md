---
name: task-planner
description: Task decomposition, planning, and tracking standards.
  Use when breaking down complex work or managing multi-step tasks.
---

# Task Planner Standards

## Task Management
1. **Plan First:** Write plan with checkable items before starting.
2. **Verify Plan:** Check in with the user before executing.
3. **Track Progress:** Mark items complete as you go.
4. **Explain Changes:** High-level summary at each step.
5. **Document Results:** Add review section when complete.
6. **Capture Lessons:** Update `.memory/LESSONS.md` after corrections.

## Task Quality
- Tasks must be clear, specific, and actionable.
- Complex tasks must be broken into atomic, trackable subtasks.
- Dependencies between tasks must be explicitly declared.
- Security-related tasks must undergo mandatory review.
- Escalate ambiguous or contradictory tasks for clarification.

## Blueprint Check (if configured)

If `Blueprint Path` is set in `.memory/CONFIG.md` and the task involves shared
business logic:
- [ ] Read the relevant spec(s) in `[BLUEPRINT_PATH]/specs/` before planning.
- [ ] Check `[BLUEPRINT_PATH]/parity/PARITY_MATRIX.md` for current platform status.
- [ ] Include in the plan: "Requires Knowledge Bus entry" if the change affects
      cross-platform contracts.
- [ ] Note any spec gaps — if the spec is missing or incomplete, plan a spec
      update as part of the task.

Skip this section if no blueprint is configured or the task is project-specific.

## Change Tracking
- All rule or config changes must be documented in CHANGELOG.md.
- Record source, timestamp, and rationale when modifying shared assets.
- A rollback plan must be defined for every major change.

## Subagent Strategy

When a task benefits from fresh context, parallel execution, or isolated scope,
use the **`subagent-dispatch`** skill. It provides prompt templates for
implementer, reviewer, and researcher subagents with explicit scope boundaries
and result validation.
