---
name: test-driven-development
license: MIT
description: When implementing logic changes during develop-feature or implement-task. Use the Red-Green-Refactor cycle to write a failing test before any production code.
---

# Test-Driven Development Skill

**Cycle: RED → GREEN → REFACTOR**

Highly recommended during any logic implementation. Do not write production code before a failing test exists.

## RED Phase — Write a Failing Test
1. Identify the smallest unit of behavior to implement next.
2. Write a test that asserts the expected output or behavior.
3. Run the test. **Confirm it fails.**
   - If it passes before any implementation, the test is wrong — fix it.
   - Record: `[RED] <test name> — fails as expected`

## GREEN Phase — Minimum Code to Pass
4. Write the minimum production code to make the test pass.
   - No premature abstractions. No extra features. Bare minimum only.
5. Run the test. **Confirm it passes.**
   - Record: `[GREEN] <test name> — passes`

## REFACTOR Phase — Clean Without Changing Behavior
6. Refactor implementation if needed (remove duplication, improve names, simplify).
7. Run the full test suite. **All tests must still pass.**
   - Record: `[REFACTOR] <test name> — clean, all pass`

## Rules
- Never skip RED. A test that was never failing proves nothing.
- Refactor only when GREEN — never while RED.
- One cycle = one behavior unit. Do not batch multiple behaviors into one RED-GREEN.
- Note failing test evidence in RESUME.md before moving to the next unit.

## Exemptions
Skip this cycle only for: trivial config/boilerplate, pure UI layout with no logic,
or when the user explicitly opts out. Document the exemption reason.

---

**Gate:** Do not write production code for a behavior unit without first having a failing test for that unit.
