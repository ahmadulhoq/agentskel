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

## Platform Standards

<!-- PLATFORM: Android -->
### Android / Kotlin
- Use `viewModelScope` in ViewModels, `lifecycleScope` in UI.
  Never use `GlobalScope` unless explicitly justified.
- Use `Flow` for reactive streams, `suspend fun` for one-shot operations.
- Prefer non-nullable types. Avoid `!!`. Use `?.let`, `?:`, or `requireNotNull()`.
- Use `data class` for pure data holders with `val` properties.
- Composables are pure functions of state. Each screen exposes a single
  `StateFlow<UiState>`. Collect with `collectAsStateWithLifecycle()`.
  One-off events via `SharedFlow<UiEvent>` or `Channel` — never in `UiState`.
- Coroutine dispatchers: `Dispatchers.IO` for blocking I/O, `Dispatchers.Default`
  for CPU work, `Dispatchers.Main` for UI only.
- New code must pass Detekt. Run `./gradlew detekt --continue` locally before
  opening a PR.
- If the task touches version/dependency files (`libs.versions.toml`,
  `gradle-wrapper.properties`, `buildSrc/`), follow
  `.agents/standards/DEPENDENCY_MANAGEMENT.md`.
- Comply with `.agents/standards/ANDROID_ARCHITECTURE.md` and
  `.agents/standards/STYLE_GUIDE.md`.
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### iOS / Swift
- Use `async/await` for new code. Use `@MainActor` for UI-bound types.
- Prefer `guard let` for early returns. Avoid force unwrapping (`!`).
- SwiftUI views are pure functions of state. Use `@StateObject` for owned
  ViewModels, `@ObservedObject` for injected ones.
- New code must pass SwiftLint. Fix all violations before opening a PR.
- If the task touches `Package.swift` or `Podfile`, follow
  `.agents/standards/DEPENDENCY_MANAGEMENT.md`.
- Comply with `.agents/standards/IOS_ARCHITECTURE.md` and
  `.agents/standards/STYLE_GUIDE.md`.
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: Web -->
### Web / Frontend
- Prefer `const` over `let`. Never use `var`. Use strict TypeScript where available.
- Component rendering must be pure. Side effects in hooks/lifecycle methods only.
- Bundle size awareness: lazy-load routes, monitor bundle budgets.
- New code must pass ESLint/Prettier. Fix all violations before opening a PR.
- If the task touches `package.json`, follow
  `.agents/standards/DEPENDENCY_MANAGEMENT.md`.
<!-- END PLATFORM: Web -->

<!-- PLATFORM: Backend -->
### Backend
- Use the language's async primitives for I/O-bound work.
- Follow the framework's recommended patterns for request handling, middleware,
  and error propagation.
- New code must pass the project's linter. Fix all violations before opening a PR.
- If the task touches dependency files, follow
  `.agents/standards/DEPENDENCY_MANAGEMENT.md`.
<!-- END PLATFORM: Backend -->

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
