---
name: senior-developer
description: Code quality standards, SOLID principles, design philosophy,
  and performance requirements. Use when writing, modifying, or
  refactoring application code.
---

# Senior Developer Standards

## User Experience First
Every code decision must consider its impact on the end user.
- **Performance:** Avoid unnecessary allocations, redundant calculations,
  and blocking the main thread or event loop. Profile before and after
  significant changes.
- **Memory:** Be mindful of memory footprint, especially in modules that
  handle images, large datasets, or streaming data.
- **Responsiveness:** UI must remain smooth. Offload computation to
  background threads or async workers.

## Design Philosophy
- **KISS:** Solutions must be straightforward. Avoid over-engineering.
- **DRY:** Don't repeat yourself. Extract shared logic rather than copying it,
  but only when the abstraction is genuinely reusable — not just coincidentally similar.
- **YAGNI:** Don't add speculative features unless the user explicitly
  requests extensibility or future-proofing. If you believe a feature
  is likely to be extended, ask the user before defaulting to the
  simplest implementation.

## SOLID Principles
- **Single Responsibility:** Each module or function does one thing only.
- **Open-Closed:** Open for extension, closed for modification.
- **Liskov Substitution:** Derived classes must be substitutable for base types.
- **Interface Segregation:** Prefer specific interfaces over general-purpose ones.
- **Dependency Inversion:** Depend on abstractions, not concrete implementations.

## Code Quality
- All public functions must include a concise, purpose-driven doc comment.
- Implement structured error handling with specific failure modes.
- Verify preconditions before executing critical or irreversible operations.
- Long-running operations must implement timeout and cancellation mechanisms.
- File and path operations must verify existence and permissions.
- Don't leave commented-out code. Provide detailed commit messages explaining *why*.

## Process
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky, implement the elegant solution instead.
- Skip this for simple, obvious fixes — don't over-engineer.
- Challenge your own work before presenting it.

## System Extension
- New modules must conform to existing interface and logging structures.
- Utility functions must be unit tested before shared use.
- New features must maintain backward compatibility unless justified.
- All changes must include a performance impact assessment.
