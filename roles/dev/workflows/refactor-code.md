---
name: refactor-code
description: When restructuring, renaming, or reorganising existing code without changing its external behavior. Use instead of develop-feature when no new functionality is being added.
---

# Refactor Code Workflow

**Purpose:** Restructure code safely — behavior preserved, tests green throughout. Output is cleaner code with identical externally-observable behavior.

## Strict Rules
- **DO NOT change behavior while refactoring.** If you discover a bug or want to add logic, stop and open a separate task.
- **Tests must pass after every atomic step.** Never commit a refactor mid-step with failing tests.
- **Scope is fixed at Phase 1.** Do not expand scope mid-refactor without user approval.

## Phase 1: Characterize & Safety Net
1. Read `.memory/RULES.md`, `.memory/MAP.md`, `.memory/SACRED.md`.
2. Use `codebase-navigator` to understand code structure via MAP.md/SYMBOLS.md.
3. Identify the refactor target: what code, what smell, what goal.
3. Run the existing test suite. **Record the baseline** — all tests must pass before you begin.
   - If tests are failing before the refactor, stop. Fix them first or get explicit approval to proceed with known failures.
4. Identify coverage gaps for the code being refactored.
   - If critical paths lack test coverage, write characterization tests first.
   - **Gate:** Do not proceed without a safety net of passing tests covering the target code.

## Phase 2: Scope & Plan
5. State the refactor type and boundaries:

   | Refactor type | Example |
   |---------------|---------|
   | Rename / move | Rename class, move module to new package |
   | Extract | Pull inline logic into a named function/class |
   | Inline | Collapse a single-use abstraction |
   | Reorder / restructure | Reorganise file layout, parameter order |
   | Pattern adoption | Apply strategy/factory/etc. to existing logic |

6. Write an explicit **out-of-scope** list — behavior changes, dependency upgrades, and bug fixes that will NOT happen in this PR.
7. Break the refactor into atomic steps, each leaving tests green.
8. Present the plan and out-of-scope list to the user. **Wait for explicit approval.**
   **Concerns and tradeoffs alone are not a plan.** A plan must state: (1) proposed
   approach, (2) files to modify, (3) open decision points.

## Phase 3: Execute (step-by-step)
9. Follow `developer` skill standards.
   For large refactors with independent modules, use `subagent-dispatch` to parallelize per module.
10. Execute one atomic step at a time.
11. After each step: run tests. If any fail, fix before proceeding.
11. If you discover a bug mid-refactor, note it and continue — do not fix it in this PR.
12. If scope unexpectedly grows (a simple rename requires touching 30 files), stop and reassess with the user before continuing.

## Phase 4: Verify & Ship
13. Run the full test suite — no regressions allowed.
14. Run static analysis if configured.
15. Confirm no behavioral changes were introduced (diff review: logic should be structurally identical, just reorganised).
16. Update `.memory/MAP.md` and `.memory/SYMBOLS.md` if structure changed.
17. Follow `git-flow` to commit and open a PR.
    - PR description must state: "No behavior changes. Refactor only."

---

## Final Step — Task Completion Checklist
Before responding to the user, run the Task Completion Checklist from `core-behavior.md`.

---

**Gate:** Do not modify production code until Phase 1 safety net is confirmed. Do not add, fix, or change behavior — that belongs in a separate task.
