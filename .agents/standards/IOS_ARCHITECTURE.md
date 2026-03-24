# iOS Architecture Guide
> Last updated: 2026-03-24
> Platform: iOS (Swift, SwiftUI)
> Based on: Apple Human Interface Guidelines + Swift concurrency
> Universal principles: `.agents/standards/ARCHITECTURE.md`
> Adapt examples below to match your project's domain.

This document is the authoritative iOS architecture reference for all engineers and agents. UI is **SwiftUI-first**. UIKit-based screens are legacy — new screens must use SwiftUI.

**When in doubt about any iOS implementation detail — APIs, patterns, SwiftUI behaviour, system frameworks — consult the official Apple documentation at https://developer.apple.com first.** This document records project decisions on top of the official guidance; it does not replace it.

---

## 1. Layered Architecture

```
┌──────────────────────────────────────┐
│           UI Layer                   │
│  SwiftUI Views                       │
│  ViewModels (screen-level)           │
├──────────────────────────────────────┤
│        Domain Layer (optional)       │
│  Use Cases / Interactors             │
├──────────────────────────────────────┤
│           Data Layer                 │
│  Repositories                        │
│  Data Sources (Remote / Local)       │
└──────────────────────────────────────┘
```

Data flows upward. Events flow downward. No layer communicates with a layer above it.

---

## 2. UI Layer — SwiftUI

### UI Framework

All new UI is written in **SwiftUI**. UIKit screens and Storyboards are not used for new screens.

- Single entry point via `@main` `App` struct.
- Each screen is a SwiftUI `View`.
- Navigation via **NavigationStack** (iOS 16+).
- Design system: follow **Apple Human Interface Guidelines**.

### State holders

| State type | Tool | When |
|-----------|------|------|
| Screen-level state | `ViewModel` + `@Published` / `@Observable` | Survives view re-creation; accesses data/domain layer; shared across subviews |
| Local UI state | `@State` | Purely presentational; scoped to one view; no data layer access |

Never reach for a ViewModel for local state that a `@State` can handle.

### UI State

Immutable struct per screen. **Naming convention:** `[Screen]UiState`

```swift
struct HomeUiState: Equatable {
    var items: [Item] = []
    var isLoading: Bool = false
    var error: String? = nil
}

// Derived state as computed property — not stored in the struct
extension HomeUiState {
    var hasError: Bool { error != nil }
}
```

### UDF — ViewModel Pattern

```swift
// Events from UI to ViewModel
enum HomeUiEvent {
    case refresh
    case selectItem(Item)
}

// One-shot effects (navigation, alerts) — not persistent state
enum HomeUiEffect: Equatable {
    case showAlert(message: String)
    case navigateToDetail(itemId: String)
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var state = HomeUiState()

    private let getItemsUseCase: GetItemsUseCase
    private var effectContinuation: AsyncStream<HomeUiEffect>.Continuation?
    lazy var effects: AsyncStream<HomeUiEffect> = {
        AsyncStream { self.effectContinuation = $0 }
    }()

    init(getItemsUseCase: GetItemsUseCase) {
        self.getItemsUseCase = getItemsUseCase
    }

    func onEvent(_ event: HomeUiEvent) {
        switch event {
        case .refresh:
            loadItems()
        case .selectItem(let item):
            effectContinuation?.yield(.navigateToDetail(itemId: item.id))
        }
    }

    private func loadItems() {
        state.isLoading = true
        Task {
            do {
                let items = try await getItemsUseCase()
                state = HomeUiState(items: items, isLoading: false)
            } catch {
                state.isLoading = false
                effectContinuation?.yield(.showAlert(message: error.localizedDescription))
            }
        }
    }
}
```

### Observing state in SwiftUI

```swift
struct HomeScreen: View {
    @StateObject private var viewModel: HomeViewModel

    init(getItemsUseCase: GetItemsUseCase) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(getItemsUseCase: getItemsUseCase))
    }

    var body: some View {
        HomeContent(
            state: viewModel.state,
            onEvent: viewModel.onEvent
        )
        .task {
            for await effect in viewModel.effects {
                switch effect {
                case .showAlert(let message):
                    // handle alert
                    break
                case .navigateToDetail:
                    // handle navigation
                    break
                }
            }
        }
    }
}

// Stateless inner view — receives state and callbacks, no ViewModel knowledge
struct HomeContent: View {
    let state: HomeUiState
    let onEvent: (HomeUiEvent) -> Void

    // Local UI state — no ViewModel needed
    @State private var isFilterExpanded = false

    var body: some View {
        List(state.items) { item in
            Text(item.name)
                .onTapGesture { onEvent(.selectItem(item)) }
        }
        .overlay { if state.isLoading { ProgressView() } }
    }
}
```

**State hoisting:** Pass state down, pass events up. Views below the screen level receive state as parameters and closures — they never hold a ViewModel reference.

### ViewModel Rules

- **Always** use structured concurrency with `Task` inside `@MainActor` ViewModels.
- **Never** import UIKit in a ViewModel.
- **Never** call another ViewModel from a ViewModel.
- Business logic belongs in use cases or repositories — not in the ViewModel.
- Do not access `Bundle` or localization directly in a ViewModel — emit structured data and let views format it.

---

## 3. Navigation — NavigationStack

Single `App` entry point. All navigation via `NavigationStack` and `NavigationPath`.

```swift
// :Core:Navigation — shared route definitions
enum AppRoute: Hashable {
    case home
    case itemDetail(itemId: String)
    case settings
}

// Feature module registers its own navigation destinations
extension View {
    func withHomeNavigationDestinations() -> some View {
        self.navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .home:
                HomeScreen(getItemsUseCase: /* injected */)
            case .itemDetail(let itemId):
                ItemDetailScreen(itemId: itemId)
            case .settings:
                SettingsScreen()
            }
        }
    }
}

// App shell
@main
struct MyApp: App {
    @State private var path = NavigationPath()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                HomeScreen(getItemsUseCase: /* injected */)
                    .withHomeNavigationDestinations()
            }
        }
    }
}
```

- Type-safe routes using `Hashable` enums or structs.
- Features define their own `navigationDestination` modifiers — no feature knows about other features' routes.
- Deep links handled via the root `App` struct using `onOpenURL`.

---

## 4. Domain Layer (Use Cases)

### When to use

- Business logic is **complex** and would bloat the ViewModel.
- The same logic is **reused by multiple ViewModels**.

Do not create use cases for every simple operation — direct repository access from a ViewModel is fine for straightforward CRUD.

### Structure

**Naming convention:** `[Verb][Noun]UseCase`

```swift
final class GetItemsUseCase {
    private let itemRepository: ItemRepositoryProtocol
    private let settingsRepository: SettingsRepositoryProtocol

    init(itemRepository: ItemRepositoryProtocol,
         settingsRepository: SettingsRepositoryProtocol) {
        self.itemRepository = itemRepository
        self.settingsRepository = settingsRepository
    }

    func callAsFunction() async throws -> [Item] {
        let settings = try await settingsRepository.currentSettings()
        return try await itemRepository.getItems(filter: settings.filter)
    }
}
```

Rules:
- Main-safe — safe to call from the main actor.
- No mutable state. No lifecycle of their own.
- Use `callAsFunction()` so the use case can be invoked like a function.
- Heavy CPU work uses `Task.detached` or explicit actor isolation; I/O stays in the data layer.

---

## 5. Data Layer

### Components

```
Repository
  ├── RemoteDataSource   (URLSession / API client)
  └── LocalDataSource    (SwiftData / CoreData / UserDefaults)
```

Data sources are never accessed directly from outside the data layer.

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Repository protocol | `[DataType]RepositoryProtocol` | `ItemRepositoryProtocol` |
| Repository impl | `[DataType]Repository` | `ItemRepository` |
| Remote data source | `[DataType]RemoteDataSource` | `ItemRemoteDataSource` |
| Local data source | `[DataType]LocalDataSource` | `ItemLocalDataSource` |
| API client | `[DataType]APIClient` | `ItemAPIClient` |

Do not name data sources after their implementation detail (`UserDefaultsDataSource`) — name after the data type.

### Repository Pattern

```swift
protocol ItemRepositoryProtocol {
    func getItems(filter: ItemFilter) async throws -> [Item]
    func observeItems() -> AsyncStream<[Item]>
    func syncItems() async throws
}

final class ItemRepository: ItemRepositoryProtocol {
    private let remoteDataSource: ItemRemoteDataSource
    private let localDataSource: ItemLocalDataSource

    init(remoteDataSource: ItemRemoteDataSource,
         localDataSource: ItemLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func observeItems() -> AsyncStream<[Item]> {
        localDataSource.observeItems()
    }

    func syncItems() async throws {
        let items = try await remoteDataSource.fetchItems()
        try await localDataSource.saveItems(items)
    }

    func getItems(filter: ItemFilter) async throws -> [Item] {
        try await localDataSource.getItems(filter: filter)
    }
}
```

### Source of Truth

For offline-first features: **local persistence (SwiftData/CoreData) is the source of truth**. Sync writes to the local store; UI observes local store via `AsyncStream`. Never emit network data directly to the UI.

```
Network → Repository → SwiftData (SSOT) → AsyncStream → ViewModel → SwiftUI
```

### Data Layer Rules

- Repositories expose `async` functions for one-shot ops, `AsyncStream` for observable data.
- All data exposed from repositories is **immutable** (value types / structs).
- Model objects in the data layer are separate from persistence models — map at the boundary.
- **Never** use `NSManagedObject` outside the data layer. Map to plain Swift structs.
- Data sources are never accessed from outside the data layer.

---

## 6. Module Graph & Enforcement

### SPM target structure

```
App
  └── :Feature:[Name]       ← SwiftUI Views, ViewModel, navigation
        ├── :Data:[Name]    ← Repository + data sources
        │     └── :Core:Model
        │     └── :Core:Contracts
        ├── :Core:UI         ← Shared SwiftUI components, design tokens
        └── :Core:[Name]    ← Shared infrastructure (networking, analytics, etc.)

:Core:Navigation  ← route definitions shared across features
:Core:Contracts   ← pure Swift protocols, no UIKit/SwiftUI
:Data:Stubs       ← fake implementations for previews/tests only
```

### Forbidden edges

| From | To | Reason |
|------|----|--------|
| `:Data:*` | `:Feature:*` | Data must not know features exist |
| `:Data:*` | `:Data:*` | Data modules are independent |
| `:Feature:*` | `:Feature:*` | Features are independent |
| `:Core:Contracts` | anything | Contracts are pure protocols |

### Enforcement

Use a build plugin or CI script that parses `Package.swift` dependencies and fails on forbidden edges. Alternatively, use Periphery or custom linting to detect violations.

---

## 7. Cross-Module Communication

Replace `NotificationCenter` broadcasts with typed protocol contracts in `:Core:Contracts` — pure Swift, no UIKit.

```swift
// :Core:Contracts
protocol SettingsEventEmitter {
    var themeChanges: AsyncStream<Theme> { get }
}
```

Data modules implement. Feature modules depend on the protocol. The app target wires the concrete implementation. No module knows another's concrete class.

```swift
// App target — composition root
let settingsRepo = SettingsRepository(/* ... */)
let homeViewModel = HomeViewModel(
    getItemsUseCase: GetItemsUseCase(itemRepository: itemRepo, settingsRepository: settingsRepo)
)
```

---

## 8. Dependency Injection

Use **constructor injection** everywhere. For SwiftUI-specific needs, use `@Environment`.

```swift
// Constructor injection — preferred
final class HomeViewModel: ObservableObject {
    private let getItemsUseCase: GetItemsUseCase

    init(getItemsUseCase: GetItemsUseCase) {
        self.getItemsUseCase = getItemsUseCase
    }
}

// @Environment for SwiftUI services
private struct ItemRepositoryKey: EnvironmentKey {
    static let defaultValue: ItemRepositoryProtocol = ItemRepository.placeholder
}

extension EnvironmentValues {
    var itemRepository: ItemRepositoryProtocol {
        get { self[ItemRepositoryKey.self] }
        set { self[ItemRepositoryKey.self] = newValue }
    }
}
```

Rules:
- No `static let shared` singletons. Wire dependencies at the composition root (App struct).
- No service locator pattern. Constructor injection everywhere.
- For testing, pass protocol-typed dependencies — swap with fakes in tests.
- If using a DI container (e.g., Factory, swift-dependencies), keep registration at the app target.

---

## 9. General Best Practices

- **Don't store data in views.** The `App` struct is an entry point — it hosts the view hierarchy and nothing else.
- **Reduce UIKit dependencies.** Only the UI layer touches `UIApplication` or `UIKit`. Everything below is pure Swift.
- **Expose as little as possible.** Keep module internals `internal` or `private`. Public API is the minimum necessary.
- **Drive UI from data models.** Local persistence is the persistent layer. UI observes it via `AsyncStream` — it always has data, even offline.
- **Single Source of Truth per data type.** Only the owner mutates. Others observe.
- **Prefer value types.** Use structs for models and state. Use classes only for reference semantics (ViewModels, data sources).

---

## 10. Key References

- **Apple Architecture:** https://developer.apple.com/documentation/swiftui/model-data
- **SwiftUI documentation:** https://developer.apple.com/documentation/swiftui
- **Swift concurrency:** https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
- **NavigationStack:** https://developer.apple.com/documentation/swiftui/navigationstack
- **SwiftData:** https://developer.apple.com/documentation/swiftdata
- **Apple Human Interface Guidelines:** https://developer.apple.com/design/human-interface-guidelines
- **Universal principles:** `.agents/standards/ARCHITECTURE.md`
