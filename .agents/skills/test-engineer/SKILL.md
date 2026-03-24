---
name: test-engineer
description: Testing standards, simulation rules, and CI/CD requirements.
  Use when writing tests, validating changes, or working with CI pipelines.
---

# Test Engineer Standards

## Testing Rules
- All new logic must include unit and integration tests.
- Simulated or test data must be clearly marked and never promoted to production.
- All tests must pass in CI pipelines before deployment.
- Code coverage should exceed 85% on business logic modules.
- Regression tests must be defined for all high-impact updates.
- Log test outcomes in separate test logs, not production logs.

## Test Structure

<!-- PLATFORM: Android -->
### Android
- Prefer unit tests over instrumented tests when business logic is isolated.
- Use **MockK** for mocking. Use **Espresso** for UI testing.
- Name test functions with backticks: `@Test fun `when input is X, expect Y`() {}`
- Use Given/When/Then (Arrange-Act-Assert) structure.
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### iOS
- Use **XCTest** for unit and integration tests. Use **XCUITest** for UI testing.
- Use protocol-based fakes over mocking frameworks where possible.
- Name tests descriptively: `test_scenario_expectedOutcome`.
- Use Given/When/Then (Arrange-Act-Assert) structure.
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: Web -->
### Web
- Use **Jest** or **Vitest** for unit tests. Use **Playwright** or **Cypress** for E2E.
- Name tests descriptively: `it('should do X when Y')`.
- Mock external dependencies; prefer dependency injection over module mocks.
- Use Given/When/Then (Arrange-Act-Assert) structure.
<!-- END PLATFORM: Web -->

<!-- PLATFORM: Backend -->
### Backend
- Use the language's standard test framework.
- Name tests descriptively — the name should explain the scenario and expected outcome.
- Use the project's standard mocking library for test doubles.
- Use Given/When/Then (Arrange-Act-Assert) structure.
<!-- END PLATFORM: Backend -->

## Verification
- Diff behavior between main and your changes when relevant.
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness.

## Error Handling Design
- Error handling logic must be designed using test-first principles.
- Retry logic must include exponential backoff and failure limits.
