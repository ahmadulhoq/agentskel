---
name: systematic-debugger
description: When diagnosing a bug, tracing an error, or fixing unexpected behavior.
  Enforces structured root cause analysis and prohibits guess-and-check code changes.
---

# Systematic Debugger Skill

**Purpose:** Stop hallucination loops. Every code change requires a verified hypothesis and a failing test first.

## Prohibited Behaviors
- Adding `console.log` / `print` / debug statements without a stated hypothesis.
- Changing code to "see what happens."
- Fixing code before a failing test exists.
- Treating the first hypothesis as confirmed without ruling out alternatives.

## Techniques

| Technique | When to use |
|-----------|-------------|
| Root Cause Tracing | Follow the call stack up to the originating decision point |
| Defense in Depth | Audit every layer: input validation → business logic → persistence |
| Bisect | Binary-search commits or code paths to find the introduction point |

## Required Steps (in order)
1. **Reproduce** the bug reliably. If unable, state why and stop.
2. **Hypothesize:** "The bug is caused by [X] because [evidence Y]."
3. **List alternatives:** at least 2 other hypotheses to rule out.
4. **Create a failing test** that reproduces the bug. Run it — must fail.
5. **Isolate root cause** using a technique above. Rule out alternatives explicitly.
6. **Fix** with minimum code targeting the confirmed root cause only.
7. **Verify:** failing test now passes; full suite has no regressions.
8. **Log:** update `.memory/LESSONS.md` with root cause + prevention rule.

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I'll just try changing X and see" | That's the loop we're breaking | State a hypothesis first |
| "The test is hard to write here" | Difficulty ≠ exemption | Document why and get explicit sign-off |
| "I'm pretty sure it's Y" | Pretty sure ≠ confirmed | Rule out alternatives before fixing |
| "I'll add a log to check" | Logs without hypotheses produce noise | State what you expect the log to show first |

---

**Gate:** Do not change production code until step 4 (failing test) is complete and
step 5 (root cause confirmed) is documented.
