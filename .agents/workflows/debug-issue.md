---
name: debug-issue
description: When the user reports a bug, an error, or unexpected behavior. Enforces four structured phases — reproduction, failing test, root cause isolation, fix and verify — to stop guess-and-check loops.
---

# Debug Issue Workflow

**Purpose:** Structured bug diagnosis. No code changes without a confirmed hypothesis and a failing test.

## Pre-Flight
1. Read `.memory/RULES.md`, `.memory/MAP.md`, `.memory/SACRED.md`.
2. Read the bug report / error message carefully. Identify what is observable vs. assumed.

## Phase 1: Reproduction & Hypothesis
3. Use `systematic-debugger` skill for hypothesis-first analysis.
   Use `codebase-navigator` to find relevant code via MAP.md/SYMBOLS.md.
   **Atlassian integration (conditional).** If the debug was triggered from a Jira
   ticket (user referenced a ticket key), use `atlassian-integration` skill to read
   the ticket for context.
4. Reproduce the bug reliably. If you cannot reproduce it, state why and stop — do not proceed.
5. State a falsifiable hypothesis:
   > "I believe the bug is caused by [X] because [evidence Y]."
5. List at least 2 alternative hypotheses to rule out later.

## Phase 2: Failing Test Creation
6. Write a test that reproduces the bug. Run it — it **must fail**.
   - If you cannot write a test (integration-only, hardware dependency), document the reason explicitly.
7. Record: `[BUG REPRODUCED] <test name> — fails as expected`

## Phase 3: Root Cause Isolation
8. Choose a technique:
   | Technique | When to use |
   |-----------|-------------|
   | Root Cause Tracing | Follow the call stack to the originating decision point |
   | Defense in Depth | Audit all layers: input validation → business logic → persistence |
   | Bisect | Binary-search commits or code paths to find the introduction point |

9. Rule out each alternative hypothesis from step 5 explicitly.
10. State the confirmed root cause with evidence.
10b. Present the proposed fix to the user. State: approach, files to modify, and
    alternatives considered. **Wait for explicit approval before writing any code.**
    Concerns and tradeoffs alone are not a plan.

## Phase 4: Fix & Verify
11. Implement the **minimal fix** targeting the confirmed root cause only.
    - Do not clean up surrounding code, add features, or refactor beyond the fix.
12. Run the failing test from Phase 2 — it **must now pass**.
13. Run the full test suite — no regressions allowed.
14. Update `.memory/LESSONS.md` with root cause and a prevention rule.
15. Follow `git-flow` to commit and open a PR.
16. **Atlassian integration (conditional).** If a ticket triggered this debug:
    - Add comment on the ticket with findings: root cause + fix summary + PR link.
    - If fix is a hotfix or significant production issue: ask user
      "Write a postmortem? (y/n)" — if yes, invoke `publish-postmortem` workflow.

---

## Final Step — Task Completion Checklist
Before responding to the user, run the Task Completion Checklist from `core-behavior.md`.

---

**Gate:** Do not modify any production code until Phase 2 (failing test) is complete
and a root cause hypothesis is explicitly stated.
