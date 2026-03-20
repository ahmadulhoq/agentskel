# Coding Style Guide

> This guide applies to all codebases.
> During setup, trim platform-specific sections to match the project's stack.

---

## 1. General Principles

- **Readability over cleverness.** Code is read 10x more than written.
- **Consistency over personal preference.** Follow existing patterns in a file.
- **Self-documenting code.** Names should explain intent. Comments explain *why*, not *what*.
- **Small, focused units.** Functions do one thing. Classes have one responsibility.
- **Fail fast and loud.** Surface errors early; never swallow exceptions silently.

---

## 2. Naming Conventions

### 2.1 Universal

| Element         | Convention     | Example                          |
|----------------|---------------|----------------------------------|
| Classes / Types | PascalCase     | `UserRepository`                 |
| Constants       | SCREAMING_SNAKE | `MAX_RETRY_COUNT`               |
| Boolean vars    | is/has/should prefix | `isAuthenticated`, `hasExpired` |

### 2.2 Language-specific defaults

Adapt to the project's primary language. Common conventions:

| Language | Functions / Methods | Variables | Packages / Modules |
|----------|-------------------|-----------|-------------------|
| Kotlin / Java | camelCase | camelCase | lowercase dot-separated |
| Swift | camelCase | camelCase | PascalCase modules |
| TypeScript / JavaScript | camelCase | camelCase | kebab-case files |
| Python | snake_case | snake_case | snake_case packages |
| Go | camelCase (unexported) / PascalCase (exported) | camelCase / PascalCase | lowercase single word |
| Rust | snake_case | snake_case | snake_case modules |

<!-- PLATFORM: Android -->
### 2.3 Android (Kotlin)

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
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### 2.4 iOS (Swift)

| Element          | Convention                     | Example                          |
|-----------------|-------------------------------|----------------------------------|
| ViewModels       | `[Feature]ViewModel`          | `SettingsViewModel`              |
| Protocols        | Descriptive noun/adjective    | `DataCalculating`                |
| Extensions       | `[Type]+[Feature]`            | `Date+Formatting`                |
| SwiftUI Views    | `[Feature]View`               | `SettingsListView`               |
<!-- END PLATFORM: iOS -->

---

## 3. Code Organization

### 3.1 File Structure

- **One primary type per file.** A file named `UserRepository.xx` contains `UserRepository`.
- **Small private helpers are allowed** in the same file if they're only used by the primary type.
- **Extensions in separate files** when they add significant functionality.
- **Maximum file length: ~400 lines.** If longer, consider splitting.

### 3.2 Import Ordering

Group imports in this order, separated by blank lines:
1. Standard library / platform framework imports
2. Third-party library imports
3. Project / internal imports

<!-- PLATFORM: Android -->
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
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
```swift
// 1. System frameworks
import Foundation
import UIKit

// 2. Third-party libraries
import Alamofire

// 3. Project modules
import CoreEngine
```
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: Python -->
```python
# 1. Standard library
import os
from datetime import datetime

# 2. Third-party
from fastapi import FastAPI
import sqlalchemy

# 3. Project
from app.services import UserService
```
<!-- END PLATFORM: Python -->

---

## 4. Language-Specific Standards

<!-- PLATFORM: Android -->
### Kotlin (Android)

#### Coroutines
- Use `viewModelScope` in ViewModels, `lifecycleScope` in UI.
- Never use `GlobalScope` unless explicitly justified.
- Always specify a dispatcher for CPU-intensive work: `withContext(Dispatchers.Default)`.
- Use `Flow` for reactive streams, `suspend fun` for one-shot operations.

#### Null Safety
- Prefer non-nullable types. Use `?` only when null has genuine meaning.
- Avoid `!!` (force unwrap). Use `?.let`, `?:`, or `requireNotNull()` with a message.
- Exception: test code may use `!!` when a null would indicate test failure.

#### Data Classes
- Use `data class` for pure data holders. Keep immutable (`val` properties). Use `copy()` for modifications.

#### Extension Functions
- Use for adding behavior to types you don't own. Keep in a dedicated `extensions/` package.
- Don't use to replace methods that should live on the class.
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### Swift (iOS)

#### Concurrency
- Use `async/await` for new code; avoid callback-based patterns.
- Use `@MainActor` for UI-bound types.
- Use `Task` for launching from synchronous contexts.

#### Optionals
- Prefer `guard let` for early returns.
- Avoid force unwrapping (`!`). Use `if let`, `guard let`, or `??`.
- Exception: `IBOutlet` properties and test assertions.

#### Protocol-Oriented Design
- Prefer protocols over class inheritance.
- Use protocol extensions for default implementations.
- Keep protocols focused — one purpose per protocol.
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: TypeScript -->
### TypeScript / JavaScript

#### Types
- Prefer `interface` over `type` for object shapes. Use `type` for unions and utility types.
- Avoid `any`. Use `unknown` when the type is genuinely unknown, then narrow.
- Use strict mode (`"strict": true` in tsconfig).

#### Async
- Use `async/await` over raw Promises. Never mix callbacks and promises.
- Always handle promise rejections — no unhandled promise warnings.

#### Immutability
- Prefer `const` over `let`. Never use `var`.
- Use `readonly` for object properties that should not be mutated.
<!-- END PLATFORM: TypeScript -->

<!-- PLATFORM: Python -->
### Python

#### Style
- Follow PEP 8. Use a formatter (Black or Ruff).
- Type hints on all public function signatures.
- Use dataclasses or Pydantic models for structured data.

#### Async
- Use `async/await` with asyncio for I/O-bound code.
- Do not mix sync and async code paths without explicit bridge functions.

#### Imports
- Use absolute imports. Avoid `from module import *`.
<!-- END PLATFORM: Python -->

<!-- PLATFORM: Go -->
### Go

#### Style
- Run `gofmt` / `goimports` on all code. No exceptions.
- Follow Effective Go and Go Code Review Comments.
- Use `error` return values — do not panic for expected failures.

#### Naming
- Exported names are PascalCase, unexported are camelCase.
- Interface names: single-method interfaces use the `-er` suffix (`Reader`, `Writer`).
- Avoid stuttering: `user.User` is bad, `user.Account` is better.
<!-- END PLATFORM: Go -->

---

## 5. Error Handling

- Define domain-specific error types (not generic `Exception`/`Error`).
- Include actionable information in error messages.
- Log errors with context (what operation, what input, what went wrong).
- Never catch-all silently. At minimum, log the error.

---

## 6. Documentation

- **Public API:** Every public class and function must have a doc comment.
- **Why, not what:** Comments explain reasoning and intent, not obvious mechanics.
- **TODO format:** `// TODO: [TICKET-ID] Description` — always include a ticket reference.
- **FIXME format:** `// FIXME: [TICKET-ID] Description` — indicates a known bug.

---

## 7. Testing

- **Test naming:** `test_[scenario]_[expectedOutcome]` or `[function]_[scenario]_[result]`.
- **Arrange-Act-Assert** pattern for all unit tests.
- **No logic in tests.** Tests should be straightforward assertions.
- **Mocking:** Use fakes/stubs over mocking frameworks where possible.
- **Coverage:** Aim for 85%+ on business logic. UI code has lower bar.

---

## 8. Git Conventions

- **Branch naming:** `TICKET-ID-short-description` (no type prefix — see `GIT_WORKFLOW.md`)
- **Commit messages:** `[type]: short description` where type is `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
- **PR size:** Keep PRs under 400 lines of code changes when possible.
- **PR description:** Include what changed, why, how to test, and any risks.

---

<!-- PLATFORM: Android -->
## 9. Resource Naming (Android)

| Resource Type | Convention | Example |
|--------------|-----------|---------|
| Strings       | `[feature]_[description]` | `settings_label` |
| Colors        | `[name]_[variant]` | `primary_dark`, `text_secondary` |
| Dimensions    | `[type]_[size]` | `margin_medium`, `text_body` |
| Styles        | `[Component].[Variant]` | `AppTheme.Settings` |
<!-- END PLATFORM: Android -->
