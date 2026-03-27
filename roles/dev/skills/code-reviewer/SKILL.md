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
<!-- PLATFORM: Android -->
   Check `.agents/standards/ANDROID_ARCHITECTURE.md`. Verify module dependency
   rules (`:feature` → `:data` OK; no `:data`↔`:data`, no `:feature`↔`:feature`).
   Check UDF in ViewModels. No `GlobalBus`/`FlowBus` for cross-module events.
<!-- END PLATFORM: Android -->
<!-- PLATFORM: iOS -->
   Check `.agents/standards/IOS_ARCHITECTURE.md`. Verify module boundaries
   and dependency direction. Check MVVM/UDF patterns in ViewModels.
<!-- END PLATFORM: iOS -->
   Check module dependency rules and layer boundaries.
5. **Lint / Static Analysis:**
<!-- PLATFORM: Android -->
   CI runs Detekt on every PR and posts inline comments via Reviewdog.
   Check that no unresolved Detekt violations exist in new/changed lines.
<!-- END PLATFORM: Android -->
<!-- PLATFORM: iOS -->
   CI runs SwiftLint. Check that no unresolved violations exist in new/changed lines.
<!-- END PLATFORM: iOS -->
<!-- PLATFORM: Web -->
   CI runs ESLint/Prettier. Check that no unresolved violations exist in new/changed lines.
<!-- END PLATFORM: Web -->
   If CI runs static analysis, the author must fix violations before approval.
6. **Performance:** Are there obvious inefficiencies? Consider UX impact.
7. **Security:** Does it follow `security-non-negotiables` rules?
8. **Tests:** Are there adequate tests for the changes?
9. **Sacred behaviors:** Does this change anything in `.memory/SACRED.md`?
10. **Dependencies:**
<!-- PLATFORM: Android -->
    If the PR touches `libs.versions.toml`, `gradle-wrapper.properties`, or `buildSrc/`,
<!-- END PLATFORM: Android -->
<!-- PLATFORM: iOS -->
    If the PR touches `Package.swift`, `Podfile`, or `.xcode-version`,
<!-- END PLATFORM: iOS -->
<!-- PLATFORM: Web -->
    If the PR touches `package.json` or lock files,
<!-- END PLATFORM: Web -->
    verify the correct upgrade tier approval was obtained per
    `.agents/standards/DEPENDENCY_MANAGEMENT.md`. Block merge if not.

## Cross-Platform Impact (if blueprint configured)

If `Blueprint Path` is set in `.memory/CONFIG.md`:
- [ ] Check whether the changes touch business logic documented in
      `[BLUEPRINT_PATH]/specs/`. If so, verify the implementation matches the spec.
- [ ] If the changes modify shared business logic (calculations, validation rules,
      data contracts), flag it: a Knowledge Bus entry may be needed.
- [ ] Check `[BLUEPRINT_PATH]/parity/PARITY_MATRIX.md` — does this change
      affect parity status for this platform?

Skip this section if no blueprint is configured.

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
