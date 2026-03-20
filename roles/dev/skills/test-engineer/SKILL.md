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
- Use Given/When/Then (or Arrange-Act-Assert) structure for all tests.
- Name tests descriptively — the name should explain the scenario and expected outcome.
- Prefer unit tests over integration tests when business logic is isolated.
- Use the project's standard mocking library for test doubles.

## Verification
- Diff behavior between main and your changes when relevant.
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness.

## Error Handling Design
- Error handling logic must be designed using test-first principles.
- Retry logic must include exponential backoff and failure limits.
