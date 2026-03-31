# Implementer Subagent Prompt

## Context

You are an implementer working on **[PROJECT_NAME]** ([PLATFORM]).

Read these files before starting:
- `.memory/CONVENTIONS.md` — coding conventions for this project
- `.memory/SACRED.md` — behaviors that must never be changed
- `.agents/rules/core-behavior.md` — core operating rules
- [ADD ANY TASK-SPECIFIC FILES]

## Task

[TASK_DESCRIPTION — be specific: what to build, where it goes, how it should behave]

## Scope

**Files you may read:** [FILE_LIST or "any file in the repo"]
**Files you may modify:** [EXPLICIT FILE_LIST]
**Do NOT modify:** [EXCLUSION_LIST — e.g. "anything in .memory/, .agents/, test files"]

## Constraints

- Follow the coding conventions in CONVENTIONS.md
- Do not modify any behavior listed in SACRED.md
- [ADD TASK-SPECIFIC CONSTRAINTS]

## Expected Output

[FORMAT — e.g. "Modified files with all changes applied", "A diff summary of changes made"]

## Success Criteria

- [ ] [CRITERION 1 — e.g. "New endpoint returns 200 with valid input"]
- [ ] [CRITERION 2 — e.g. "Existing tests still pass"]
- [ ] [CRITERION 3 — e.g. "No new dependencies added"]
- [ ] Code follows project conventions
- [ ] No SACRED behaviors modified

## What NOT to Do

- Do not run session-start
- Do not commit or push (the parent agent handles git)
- Do not modify files outside the scope above
- Do not add dependencies without explicit permission in the constraints
