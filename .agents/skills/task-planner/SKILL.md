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

## Change Tracking
- All rule or config changes must be documented in CHANGELOG.md.
- Record source, timestamp, and rationale when modifying shared assets.
- A rollback plan must be defined for every major change.

## Subagent Strategy
- Use subagents to keep main context window clean.
- Offload research, exploration, and parallel analysis to subagents.
- One task per subagent for focused execution.
