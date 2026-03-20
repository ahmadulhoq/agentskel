# Architecture Principles

> High-level architecture guidelines for all codebases.
> During setup, trim platform-specific sections to match the project's stack.

---

## 1. Layered Architecture

All projects follow a layered architecture. The layers and their rules are platform-agnostic. Each platform implements them using its native tools and patterns.

```
┌─────────────────────────────────────────────┐
│  Presentation Layer                         │
│  UI / API handlers / CLI                    │
│  State holders (ViewModels, controllers)    │
├─────────────────────────────────────────────┤
│  Domain Layer  (optional)                   │
│  Use Cases / Services                       │
│  (use only when logic is complex or shared  │
│   across multiple consumers)               │
├─────────────────────────────────────────────┤
│  Data Layer                                 │
│  Repositories                               │
│  Data Sources (Remote / Local)              │
└─────────────────────────────────────────────┘
```

Data flows upward (data layer → presentation). Events flow downward (presentation → domain → data). No layer communicates with a layer above it.

### Layer Rules

| Rule | Description |
|------|-------------|
| **Dependency direction** | Data flows up; events flow down. No reverse edges. |
| **Domain layer is optional** | Use it only for complex logic or logic reused by multiple consumers. Do not create use cases for every simple operation. |
| **Data layer is always present** | Every project has repositories. Data sources sit inside the data layer and are never accessed directly from the presentation layer. |
| **Domain has no framework deps** | Use cases and domain services are pure language code — no platform SDK imports. |
| **Data hides implementation** | The presentation layer never knows if data comes from network, database, or cache — that is the repository's concern. |
| **Single Source of Truth** | Every data type has exactly one owner. Only the owner mutates it; others observe the immutable form. |

---

## 2. Module Structure

Organise code into modules with clear boundaries. The naming conventions below are platform-specific; the principles are universal.

### Principles (all platforms)

- **Feature modules are independent** — they never depend on each other.
- **Data modules are independent** — they never depend on each other.
- **Dependency direction**: feature → data → core. Never reverse.
- **Contracts module** (interfaces/protocols) is pure abstractions — no implementations, no dependencies.
- **Cross-module communication** uses typed interfaces injected at the composition root, not shared mutable state or event buses.

<!-- PLATFORM: Android -->
### Android (Gradle Modules)

```
:app                          → Application shell, navigation, DI root
:feature:[name]               → Self-contained features (e.g., :feature:settings)
:core:[name]                  → Shared infrastructure (e.g., :core:network, :core:auth)
:lib:[name]                   → Internal libraries/engines (e.g., :lib:analytics-engine)
```
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### iOS (Swift Packages / Targets)

```
App                           → Application shell, navigation, DI root
Feature/[Name]                → Self-contained features
Core/[Name]                   → Shared infrastructure
Lib/[Name]                    → Internal libraries/engines
```
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: Backend -->
### Backend

```
cmd/ or src/                  → Application entry points
internal/ or app/             → Business logic (features, services)
pkg/ or lib/                  → Shared libraries
infrastructure/               → Database, messaging, external service clients
```

Adapt to your language's conventions (Go packages, Python packages, Node.js modules, Java packages).
<!-- END PLATFORM: Backend -->

<!-- PLATFORM: Web -->
### Web (Frontend)

```
src/
  app/                        → Application shell, routing, providers
  features/[name]/            → Self-contained features (components, hooks, state)
  shared/                     → Shared components, utilities, types
  lib/                        → Internal libraries
```
<!-- END PLATFORM: Web -->

---

## 3. Dependency Injection

### Principles (all platforms)

- Prefer constructor injection over service locators.
- Dependencies are injected as abstractions (interfaces/protocols), not concrete types.
- The composition root (app entry point) wires concrete implementations.
- Scoping: app-wide singletons for shared state, request/screen-scoped for transient state.

<!-- PLATFORM: Android -->
### Android: Hilt

- All injectable classes use constructor injection.
- Module-level `@Module` classes provide external dependencies.
- Scoping: `@Singleton` for app-wide, `@ViewModelScoped` for ViewModel-bound.
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### iOS: Constructor Injection / Manual Composition Root

- Dependencies injected via protocol abstractions.
- Composition root (app entry point) wires concrete implementations.
- `@EnvironmentObject` for app-wide dependencies passed through the SwiftUI hierarchy — use sparingly.
- No service locator pattern.
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: Backend -->
### Backend

- Use the framework's native DI (e.g., Spring DI, NestJS providers, Go wire, Python dependency-injector).
- If no framework DI: manual constructor injection at the composition root.
- Avoid global singletons and mutable module-level state.
<!-- END PLATFORM: Backend -->

---

## 4. Navigation

<!-- PLATFORM: Android -->
### Android

- Single-Activity architecture with **Compose Navigation**.
- Feature modules define their own nav graphs as `NavGraphBuilder` extensions.
- Type-safe routes using Compose Navigation 2.8+ serializable objects.
- Deep links registered in the main nav graph.
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### iOS

- **`NavigationStack`**-based navigation (iOS 16+).
- Feature modules own their navigation paths.
- `NavigationPath` for programmatic / deep-link navigation.
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: Web -->
### Web

- Use the framework's native router (React Router, Next.js App Router, Vue Router, Angular Router).
- Route definitions co-located with feature modules.
- Lazy-load feature routes for code splitting.
<!-- END PLATFORM: Web -->

<!-- PLATFORM: Backend -->
### Backend

- Route definitions co-located with feature/handler modules.
- Use the framework's native routing (Express/NestJS routers, Go mux, Django urlpatterns, FastAPI routers).
- API versioning via URL prefix (`/api/v1/`) or header — see `API_CONTRACT.md`.
<!-- END PLATFORM: Backend -->

---

## 5. Networking

- Single API client abstraction per app/service.
- Requests and responses use dedicated model classes (not domain models).
- Mappers convert API models ↔ domain models.
- All network calls handle: success, error, loading, and timeout states.
- Retry logic uses exponential backoff with configurable limits.

---

## 6. Data Persistence

### Principles (all platforms)

- Repository pattern abstracts storage implementation from domain.
- Encrypted storage for sensitive data (tokens, credentials).
- Separate config/preferences storage from structured data storage.

<!-- PLATFORM: Android -->
### Android

- **Room** for structured local storage.
- **DataStore** for key-value preferences.
- **EncryptedSharedPreferences** / **security-crypto** for sensitive data.
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### iOS

- **SwiftData** (iOS 17+) or **Core Data** for structured local storage.
- **UserDefaults** for key-value preferences.
- **Keychain** for sensitive data.
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: Backend -->
### Backend

- Use an ORM or query builder appropriate to the language (SQLAlchemy, Prisma, GORM, Room, etc.).
- Migrations managed via version-controlled migration files.
- Connection pooling for database access.
- Never store secrets in the database — use a secrets manager or environment variables.
<!-- END PLATFORM: Backend -->

---

## 7. State Management

### Principles (all platforms)

- **Unidirectional data flow (UDF):** Data flows in one direction. State holders produce state; consumers observe and render. No circular dependencies.
- **Single Source of Truth:** Each piece of state has exactly one owner.
- **Immutable state:** Expose immutable state objects. Mutations happen through defined actions/events only.

<!-- PLATFORM: Android / iOS -->
### Mobile (Android / iOS)

```
User Action → UI Event → ViewModel.onEvent() → State update → UI re-renders
```

- One ViewModel/state holder per screen or navigation destination.
- ViewModels expose a **single immutable state object** per screen.
- UI never writes state directly — it sends events.
- Side effects (navigation, toasts) are one-shot — not persistent state fields.
- ViewModels never hold references to Views or UI framework types.

#### Local UI state (no ViewModel needed)

For state that is purely presentational and scoped to a single component:

| Platform | Tool |
|----------|------|
| Android (Compose) | `remember { mutableStateOf(...) }` |
| iOS (SwiftUI) | `@State` |
<!-- END PLATFORM: Android / iOS -->

<!-- PLATFORM: Backend -->
### Backend

- Request-scoped state: passed through the handler chain, not stored globally.
- Application state: managed via DI-scoped singletons (database connections, config, caches).
- Avoid mutable global state — it breaks under concurrency.
<!-- END PLATFORM: Backend -->

<!-- PLATFORM: Web -->
### Web (Frontend)

- Use the framework's recommended state management (React Context + hooks, Vuex/Pinia, NgRx, Zustand, etc.).
- Server state (API data) managed separately from client state (UI state).
- Prefer derived/computed state over duplicated state.
<!-- END PLATFORM: Web -->

---

## 8. Background Work & Concurrency

### Principles (all platforms)

- Never block the main thread / event loop.
- Use platform-recommended concurrency primitives.
- Long-running work must support cancellation and timeout.

<!-- PLATFORM: Android -->
### Android

| Tool | Use For |
|------|---------|
| WorkManager | Deferred, guaranteed work (sync, upload) |
| AlarmManager | Exact-time triggers (scheduled notifications) |
| Foreground Service | Long-running user-visible work |
| Coroutines | Async operations within app lifecycle |

Battery: minimize wake-ups, batch background work, use platform-recommended APIs.
<!-- END PLATFORM: Android -->

<!-- PLATFORM: iOS -->
### iOS

| Tool | Use For |
|------|---------|
| BGTaskScheduler | Background fetch and processing |
| UNNotificationCenter | Scheduled notifications |
| Swift Concurrency (async/await) | Async operations |

Battery: minimize wake-ups, use BGTaskScheduler over custom timers.
<!-- END PLATFORM: iOS -->

<!-- PLATFORM: Backend -->
### Backend

- Use async I/O where available (asyncio, goroutines, Node.js event loop, virtual threads).
- Background jobs via a job queue (Celery, Bull, Sidekiq, or cloud-native: SQS, Cloud Tasks).
- Scheduled tasks via cron or the framework's scheduler — not sleep loops.
- Graceful shutdown: drain in-flight requests and complete running jobs before exit.
<!-- END PLATFORM: Backend -->

---

## 9. Security

- **Credentials** stored in platform keychain/keystore/secrets manager only.
- **API keys** provided via build configuration or environment variables, never hardcoded.
- **Network** traffic over HTTPS only. Certificate pinning for auth endpoints (mobile).
- **Input validation** at every trust boundary (API responses, user input, deep links, request bodies).
- Refer to `security-non-negotiables.md` for the full list.

---

## 10. Performance Guidelines

- **Main thread / event loop** is sacred. No blocking I/O, no heavy computation.
- **Memory** leaks are P0 bugs. Use platform leak detection tools.
- **Startup time:** minimize — lazy-load what is not needed immediately.
- Profile before and after significant changes.

<!-- PLATFORM: Android / iOS -->
### Mobile

- **UI rendering** target: 60fps minimum. Profile with platform tools.
- **App startup** must complete within 2 seconds on mid-range devices.
- **Image loading** uses caching libraries (Coil/Glide on Android, Kingfisher/SDWebImage on iOS).
<!-- END PLATFORM: Android / iOS -->

<!-- PLATFORM: Backend -->
### Backend

- **Response time** targets: define per endpoint (p50, p95, p99).
- **Database queries:** avoid N+1, use indexes, monitor slow query logs.
- **Connection pooling** for databases and external HTTP clients.
<!-- END PLATFORM: Backend -->

<!-- PLATFORM: Web -->
### Web

- **Core Web Vitals** (LCP, FID, CLS) as performance targets.
- **Bundle size:** monitor and enforce budgets. Code-split by route.
- **Image loading:** use lazy loading, responsive images, and CDN.
<!-- END PLATFORM: Web -->
