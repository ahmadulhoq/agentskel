# Coding Style Guide

> This guide applies to all app codebases.
> Platform-specific sections are clearly marked.

---

## 1. General Principles

- **Readability over cleverness.** Code is read 10x more than written.
- **Consistency over personal preference.** Follow existing patterns in a file.
- **Self-documenting code.** Names should explain intent. Comments explain *why*, not *what*.
- **Small, focused units.** Functions do one thing. Classes have one responsibility.
- **Fail fast and loud.** Surface errors early; never swallow exceptions silently.

---

## 2. Naming Conventions

### 2.1 General

| Element         | Convention     | Example                          |
|----------------|---------------|----------------------------------|
| Classes         | PascalCase     | `UserRepository`                 |
| Functions       | camelCase      | `calculateResult()`              |
| Constants       | SCREAMING_SNAKE | `MAX_RETRY_COUNT`               |
| Variables       | camelCase      | `currentItem`                    |
| Boolean vars    | is/has/should prefix | `isAuthenticated`, `hasExpired` |
| Packages        | lowercase, dot-separated | `com.example.app.feature.settings` |

### 2.2 Android (Kotlin)

| Element          | Convention                     | Example                          |
|-----------------|-------------------------------|----------------------------------|
| ViewModels       | `[Feature]ViewModel`          | `SettingsViewModel`              |
| Repositories     | `[Domain]Repository`          | `UserRepository`                 |
| UseCases         | `[Action][Entity]UseCase`     | `GetUserProfileUseCase`          |
| Fragments        | `[Feature]Fragment`           | `SettingsFragment`               |
| Activities       | `[Feature]Activity`           | `OnboardingActivity`             |
| DI Modules       | `[Feature]Module`             | `SettingsModule`                 |
| XML layouts      | `[type]_[feature]_[desc]`     | `fragment_settings_list`         |
| XML IDs          | camelCase                      | `tvUserName`                     |
| Drawable         | `ic_[name]` / `bg_[name]`    | `ic_arrow`, `bg_card`           |

### 2.3 iOS (Swift)

| Element          | Convention                     | Example                          |
|-----------------|-------------------------------|----------------------------------|
| ViewModels       | `[Feature]ViewModel`          | `SettingsViewModel`              |
| Coordinators     | `[Feature]Coordinator`        | `SettingsCoordinator`            |
| Protocols        | Descriptive noun/adjective    | `DataCalculating`                |
| Extensions       | `[Type]+[Feature]`            | `Date+Formatting`                |
| SwiftUI Views    | `[Feature]View`               | `SettingsListView`               |

---

## 3. Code Organization

### 3.1 File Structure

- **One primary type per file.** A file named `SettingsViewModel.kt` contains `SettingsViewModel`.
- **Small private helpers are allowed** in the same file if they're only used by the primary type.
- **Extensions in separate files** when they add significant functionality.
- **Maximum file length: ~400 lines.** If longer, consider splitting.

### 3.2 Import Ordering (Android/Kotlin)

```kotlin
// 1. Android/Framework imports
import android.os.*

// 2. Third-party libraries
import javax.inject.*
import dagger.hilt.*
import kotlinx.coroutines.*

// 3. Project imports
import com.example.app.*
```

### 3.3 Import Ordering (iOS/Swift)

```swift
// 1. System frameworks
import Foundation
import UIKit

// 2. Third-party libraries
import Alamofire

// 3. Project modules
import CoreEngine
```

---

## 4. Kotlin Standards (Android)

### 4.1 Coroutines

- Use `viewModelScope` in ViewModels, `lifecycleScope` in UI.
- Never use `GlobalScope` unless explicitly justified.
- Always specify a dispatcher for CPU-intensive work: `withContext(Dispatchers.Default)`.
- Use `Flow` for reactive streams, `suspend fun` for one-shot operations.

### 4.2 Null Safety

- Prefer non-nullable types. Use `?` only when null has genuine meaning.
- Avoid `!!` (force unwrap). Use `?.let`, `?:`, or `requireNotNull()` with a message.
- Exception: test code may use `!!` when a null would indicate test failure.

### 4.3 Data Classes

- Use `data class` for pure data holders.
- Keep data classes immutable (`val` properties).
- Use `copy()` for modifications.

### 4.4 Extension Functions

- Use for adding behavior to types you don't own.
- Keep in a dedicated `extensions/` package.
- Don't use to replace methods that should live on the class.

---

## 5. Swift Standards (iOS)

### 5.1 Concurrency

- Use `async/await` for new code; avoid callback-based patterns.
- Use `@MainActor` for UI-bound types.
- Use `Task` for launching from synchronous contexts.

### 5.2 Optionals

- Prefer `guard let` for early returns.
- Avoid force unwrapping (`!`). Use `if let`, `guard let`, or `??`.
- Exception: `IBOutlet` properties and test assertions.

### 5.3 Protocol-Oriented Design

- Prefer protocols over class inheritance.
- Use protocol extensions for default implementations.
- Keep protocols focused — one purpose per protocol.

---

## 6. Error Handling

- Define domain-specific error types (not generic `Exception`/`Error`).
- Include actionable information in error messages.
- Log errors with context (what operation, what input, what went wrong).
- Never catch-all silently. At minimum, log the error.

```kotlin
// Good
sealed class DataError : Exception() {
    data class CalculationFailed(val reason: String) : DataError()
    data class ResourceUnavailable(val lastAttempt: Instant) : DataError()
}

// Bad
throw Exception("something went wrong")
```

---

## 7. Documentation

- **Public API:** Every public class and function must have a KDoc/SwiftDoc comment.
- **Why, not what:** Comments explain reasoning and intent, not obvious mechanics.
- **TODO format:** `// TODO: [TICKET-ID] Description` — always include a ticket reference.
- **FIXME format:** `// FIXME: [TICKET-ID] Description` — indicates a known bug.

---

## 8. Testing

- **Test naming:** `test_[scenario]_[expectedOutcome]` or `[function]_[scenario]_[result]`.
- **Arrange-Act-Assert** pattern for all unit tests.
- **No logic in tests.** Tests should be straightforward assertions.
- **Mocking:** Use fakes/stubs over mocking frameworks where possible.
- **Coverage:** Aim for 85%+ on business logic. UI code has lower bar.

---

## 9. Git Conventions

- **Branch naming:** `feature/TICKET-ID-short-description`, `bugfix/TICKET-ID-short-description`
- **Commit messages:** `[type]: short description` where type is `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
- **PR size:** Keep PRs under 400 lines of code changes when possible.
- **PR description:** Include what changed, why, how to test, and any risks.

---

## 10. Resource Naming (Android)

| Resource Type | Convention | Example |
|--------------|-----------|---------|
| Strings       | `[feature]_[description]` | `settings_label` |
| Colors        | `[name]_[variant]` | `primary_dark`, `text_secondary` |
| Dimensions    | `[type]_[size]` | `margin_medium`, `text_body` |
| Styles        | `[Component].[Variant]` | `AppTheme.Settings` |
