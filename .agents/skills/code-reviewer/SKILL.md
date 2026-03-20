---
name: code-reviewer
description: Code review procedures, documentation standards, and QA checks.
  Use when reviewing PRs, checking code quality, or validating documentation.
---

# Code Reviewer Standards

## Review Checklist
1. **Correctness:** Does the code do what it's supposed to?
2. **Edge cases:** Are error conditions handled?
3. **Style:** Does it follow project conventions? Check `.memory/CONVENTIONS.md`.
4. **Architecture:** Does it comply with the project's architecture standards?
   Check module dependency rules and layer boundaries.
5. **Lint / Static Analysis:** Check that no unresolved violations exist in
   new or changed lines. The author must fix violations before approval.
6. **Performance:** Are there obvious inefficiencies? Consider UX impact.
7. **Security:** Does it follow `security-non-negotiables` rules?
8. **Tests:** Are there adequate tests for the changes?
9. **Sacred behaviors:** Does this change anything in `.memory/SACRED.md`?
10. **Dependencies:** If the PR touches dependency files, verify the correct
    upgrade tier approval was obtained per the project's dependency management
    standard. Block merge if not.

## Documentation Standards
- Documentation must be synchronised with code changes.
- Markdown files must use consistent heading hierarchies.
- Code snippets must be executable and reflect real use cases.
- Each doc must outline: purpose, usage, parameters, and examples.

## QA Procedures
- Changes involving security, system config, or agent roles require review.
- User-facing output must be clear, non-technical, and actionable.
- All major updates must include a rollback plan.
- Do not nit-pick code that matches the conventions in `.memory/CONVENTIONS.md`.
- Post constructive, actionable feedback — explain why, not just what.

## How to Provide Feedback
- Be specific about what needs to change.
- Explain why, not just what.
- Suggest alternatives when possible.
