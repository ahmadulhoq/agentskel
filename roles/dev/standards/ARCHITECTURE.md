# Architecture Principles

> High-level architecture guidelines for all app codebases.

---

## 1. Layered Architecture

All mobile apps — Android and iOS — follow the same layered architecture. The layers and their rules are platform-agnostic. Each platform implements them using its native tools and patterns.

Platform-specific implementation guides:
- Android: `standards/ANDROID_ARCHITECTURE.md` (based on [developer.android.com/topic/architecture](https://developer.android.com/topic/architecture))
- iOS: `standards/IOS_ARCHITECTURE.md`

```
┌─────────────────────────────────────────────┐
│  UI Layer                                   │
│  Composables / SwiftUI Views                │
│  ViewModels (screen-level state holders)     │
├─────────────────────────────────────────────┤
│  Domain Layer  (optional)                   │
│  Use Cases / Interactors                     │
│  (use only when logic is complex or shared  │
│   across multiple ViewModels)               │
├─────────────────────────────────────────────┤
│  Data Layer                                 │
│  Repositories                               │
│  Data Sources (Remote / Local)              │
└─────────────────────────────────────────────┘
```

Data flows upward (data layer → UI). Events flow downward (UI → ViewModel → data layer). No layer communicates with a layer above it.

### Layer Rules

| Rule | Description |
|------|-------------|
| **Dependency direction** | Data flows up; events flow down. No reverse edges. |
| **Domain layer is optional** | Use it only for complex logic or logic reused by multiple ViewModels. Do not create use cases for every simple operation. |
| **Data layer is always present** | Every app has repositories. Data sources sit inside the data layer and are never accessed directly from UI or domain layers. |
| **Domain has no framework deps** | Use cases are pure Kotlin — no Android SDK, no UIKit. |
| **Data hides implementation** | The UI never knows if data comes from network, database, or cache — that is the repository's concern. |
| **Screen-level state → ViewModel** | One ViewModel per navigation destination. Survives config changes. Accesses data/domain layers. |
| **Local UI state → native local state** | Toggle, animation, keyboard visibility — use `remember`/`@State`. No ViewModel needed. |
| **ViewModels don't know about Views** | ViewModels expose immutable state; Views observe and render. |
| **Single Source of Truth** | Every data type has exactly one owner. Only the owner mutates it; others observe the immutable form. |

---

## 2. Module Structure

### 2.1 Android (Gradle Modules)

```
:app                          → Application shell, navigation, DI root
:feature:[name]               → Self-contained features (e.g., :feature:settings)
:core:[name]                  → Shared infrastructure (e.g., :core:network, :core:auth)
:lib:[name]                   → Internal libraries/engines (e.g., :lib:analytics-engine)
```

### 2.2 iOS (Swift Packages / Targets)

```
App                           → Application shell, navigation, DI root
Feature/[Name]                → Self-contained features
Core/[Name]                   → Shared infrastructure
Lib/[Name]                    → Internal libraries/engines
```

### Module Dependency Rules

| Dependency | Allowed? |
|------------|----------|
| `:feature` → `:data` | Yes |
| `:feature` → `:core` / `:lib` | Yes |
| `:feature` → `:feature` | **No** — feature modules are independent |
| `:data` → `:core:model` / `:core:contracts` | Yes |
| `:data` → `:data` | **No** — data modules are independent |
| `:data` → `:feature` | **No** — never reverse the dependency |
| `:core:contracts` → anything | **No** — contracts module is pure interfaces only |
| `:lib` → anything | **No** — lib modules are fully standalone |

**Standalone-app principle:** Every feature module must be buildable as an independent app when paired with `:core:base` and stub data implementations. This is enforced by maintaining `:demo:[feature-name]` application modules. If a feature cannot be extracted into a demo app, it has hidden coupling that must be resolved.

**Cross-module communication:** Feature and data modules must not communicate via shared mutable state or event buses. Use typed interfaces defined in `:core:contracts`, injected at the `:app` level via dependency injection.

---

## 3. Dependency Injection

### Android: Hilt

- All injectable classes use constructor injection.
- Module-level `@Module` classes provide external dependencies.
- Scoping: `@Singleton` for app-wide, `@ViewModelScoped` for ViewModel-bound.

### iOS: Constructor Injection / Manual Composition Root

- Dependencies injected via protocol abstractions (constructor injection).
- Composition root (app entry point) wires concrete implementations.
- `@EnvironmentObject` for app-wide dependencies passed through the SwiftUI hierarchy — use sparingly.
- No service locator pattern — always explicit injection.

---

## 4. Navigation

### Android

- Single-Activity architecture with **Compose Navigation**.
- Feature modules define their own nav graphs as `NavGraphBuilder` extensions.
- Type-safe routes using Compose Navigation 2.8+ serializable objects.
- Deep links registered in the main nav graph.

### iOS

- **`NavigationStack`**-based navigation (iOS 16+).
- Feature modules own their navigation paths.
- `NavigationPath` for programmatic / deep-link navigation.
- No Coordinator pattern — SwiftUI navigation is declarative and self-contained.

---

## 5. Networking

- Single API client abstraction per app (e.g., `ApiService`).
- Requests and responses use dedicated model classes (not domain models).
- Mappers convert API models ↔ domain models.
- All network calls handle: success, error, loading, and offline states.
- Retry logic uses exponential backoff with configurable limits.

---

## 6. Data Persistence

- **Room** (Android) / **SwiftData** (iOS 17+) or **Core Data** (iOS 16 and below) for structured local storage.
- **DataStore/UserDefaults** for key-value preferences.
- **Encrypted storage** for sensitive data (tokens, credentials).
- Repository pattern abstracts storage implementation from domain.

---

## 7. State Management — UDF (Unidirectional Data Flow)

All ViewModels follow strict UDF: data flows in one direction only — from the data layer up to the UI. The UI sends events down; the ViewModel produces state up. No circular paths.

```
User Action → UI Event → ViewModel.onEvent() → State update → UI re-renders
```

### Screen-level state (ViewModel)

Used when state must survive configuration changes, is shared across composables/views on the screen, or requires access to the data/domain layer.

- ViewModels expose a **single immutable state object** per screen.
- UI never writes state directly — it sends events.
- Side effects (navigation, toasts, dialogs) are **one-shot** — not persistent state fields.
- ViewModels never hold references to Views, Composables, Activities, or UIViewControllers.
- ViewModels never call other ViewModels.

### Local UI state (no ViewModel needed)

Used for state that is purely presentational, scoped to a single component, and does not need to survive configuration changes or access any data layer.

| Platform | Tool |
|----------|------|
| Android (Compose) | `remember { mutableStateOf(...) }` |
| iOS (SwiftUI) | `@State` |

Examples: dropdown open/closed, text field focus, animation progress, toggle within a single component.

```kotlin
// Good: Single state object for screen-level state
data class FeatureUiState(
    val items: List<Item> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

// Good: Local state — no ViewModel needed
var isDropdownExpanded by remember { mutableStateOf(false) }

// Bad: Scattered ViewModel state
val items = MutableStateFlow<List<Item>>(emptyList())
val isLoading = MutableStateFlow(false)
val error = MutableStateFlow<String?>(null)
```

---

## 8. Background Work

| Platform | Tool | Use For |
|----------|------|---------|
| Android  | WorkManager | Deferred, guaranteed work (sync, upload) |
| Android  | AlarmManager | Exact-time triggers (scheduled notifications) |
| Android  | Foreground Service | Long-running user-visible work |
| iOS      | BGTaskScheduler | Background fetch and processing |
| iOS      | UNNotificationCenter | Scheduled notifications |

### Battery Considerations

- Minimize wake-ups. Batch background work where possible.
- Use platform-recommended APIs. No custom polling loops.
- Exact-time alarm scheduling requires exact-time alarms — this is an accepted exception when needed.
- See `.memory/SACRED.md` for device-specific workarounds that must be preserved.

---

## 9. Security

- **Credentials** stored in platform keychain/keystore only.
- **API keys** provided via build configuration, never hardcoded.
- **Network** traffic over HTTPS only. Certificate pinning for auth endpoints.
- **Input validation** at every trust boundary (API responses, user input, deep links).
- Refer to `security-non-negotiables.md` for the full list.

---

## 10. Performance Guidelines

- **Main thread** is sacred. No blocking I/O, no heavy computation.
- **UI rendering** target: 60fps minimum. Profile with platform tools.
- **App startup** must complete within 2 seconds on mid-range devices.
- **Memory** leaks are P0 bugs. Use platform leak detection tools.
- **Image loading** uses caching libraries (Coil/Glide on Android, Kingfisher on iOS).
