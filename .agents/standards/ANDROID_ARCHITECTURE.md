# Android Architecture Guide
> Last updated: [DATE]
> Platform: Android (Kotlin, Jetpack Compose, Gradle)
> Based on: https://developer.android.com/topic/architecture
> Universal principles: `roles/dev/standards/ARCHITECTURE.md`
> Adapt examples below to match your project's domain.

This document is the authoritative Android architecture reference for all engineers and agents on this project. UI is **Compose-first**. XML layouts and Fragment-based UI are legacy — new screens must use Compose.

**When in doubt about any Android implementation detail — APIs, patterns, Compose behaviour, Jetpack libraries — consult the official Android documentation at https://developer.android.com first.** This document records project-level decisions on top of the official guidance; it does not replace it.

---

## 1. Layered Architecture

```
┌──────────────────────────────────────┐
│           UI Layer                   │
│  Composables                         │
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

## 2. UI Layer — Jetpack Compose

### UI Framework

All new UI is written in **Jetpack Compose**. XML layouts and Fragment-based UI are not used for new screens.

- Single `Activity` as the app shell.
- Each screen is a `@Composable` function.
- Navigation between screens via **Compose Navigation**.
- Design system: **Material3** (`androidx.compose.material3`).

### State holders

| State type | Tool | When |
|-----------|------|------|
| Screen-level state | `ViewModel` + `StateFlow` | Survives config change; accesses data/domain layer; shared across multiple composables on the screen |
| Local UI state | `remember { mutableStateOf(...) }` | Purely presentational; scoped to one composable; no data layer access |

Never reach for a ViewModel for local state that a `remember` can handle.

### UI State

Immutable data class per screen. **Naming convention:** `[Screen]UiState`

```kotlin
data class HomeUiState(
    val items: List<Item> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

// Derived state as extension property — not stored in the class
val HomeUiState.hasError: Boolean get() = error != null
```

### UDF — ViewModel Pattern

```kotlin
// Events from UI to ViewModel
sealed class HomeUiEvent {
    data object Refresh : HomeUiEvent()
    data class SelectItem(val item: Item) : HomeUiEvent()
}

// One-shot effects (navigation, snackbars) — not persistent state
sealed class HomeUiEffect {
    data class ShowSnackbar(val message: String) : HomeUiEffect()
    data object NavigateToSettings : HomeUiEffect()
}

class HomeViewModel @Inject constructor(
    private val getItemsUseCase: GetItemsUseCase
) : ViewModel() {

    private val _state = MutableStateFlow(HomeUiState())
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    private val _effects = Channel<HomeUiEffect>(Channel.BUFFERED)
    val effects: Flow<HomeUiEffect> = _effects.receiveAsFlow()

    fun onEvent(event: HomeUiEvent) = when (event) {
        is HomeUiEvent.Refresh -> loadItems()
        is HomeUiEvent.SelectItem -> handleSelection(event.item)
    }

    private fun loadItems() = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        getItemsUseCase()
            .onSuccess { items -> _state.update { it.copy(items = items, isLoading = false) } }
            .onFailure { e -> _effects.send(HomeUiEffect.ShowSnackbar(e.message ?: "Error")) }
    }
}
```

### Collecting state in Compose

**Always** use `collectAsStateWithLifecycle()` — it is lifecycle-aware and stops collection when the composable is not active, saving resources.

```kotlin
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Collect one-shot effects
    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is HomeUiEffect.ShowSnackbar -> snackbarHostState.showSnackbar(effect.message)
                is HomeUiEffect.NavigateToSettings -> { /* navigate */ }
            }
        }
    }

    HomeContent(
        state = state,
        onEvent = viewModel::onEvent
    )
}

// Stateless inner composable — receives state and callbacks, no ViewModel knowledge
@Composable
fun HomeContent(
    state: HomeUiState,
    onEvent: (HomeUiEvent) -> Unit
) {
    // Local UI state — no ViewModel needed
    var isFilterExpanded by remember { mutableStateOf(false) }

    // Render state...
}
```

**State hoisting:** Pass state down, pass events up. Composables below the screen level receive state as parameters and callbacks — they never hold a ViewModel reference.

### ViewModel Rules

- **Always** `viewModelScope` — never `CoroutineScope(Dispatchers.*)` raw in a ViewModel.
- **Never** pass `Activity`, `Context`, or any Android framework reference into a ViewModel constructor or function.
- **Never** call another ViewModel from a ViewModel.
- Business logic belongs in use cases or repositories — not in the ViewModel.
- Do not call `getString()` or access resources in a ViewModel — emit resource IDs or structured data.

---

## 3. Navigation — Compose Navigation

Single Activity. All navigation via `NavHost`.

```kotlin
// :core:navigation — shared route definitions
@Serializable object HomeRoute
@Serializable data class DetailRoute(val itemId: String)

// Feature module registers its own graph
fun NavGraphBuilder.homeGraph(navController: NavController) {
    navigation<HomeRoute>(startDestination = HomeListRoute) {
        composable<HomeListRoute> {
            HomeScreen(
                onNavigateToDetail = { id ->
                    navController.navigate(DetailRoute(id))
                }
            )
        }
        composable<DetailRoute> { backStackEntry ->
            val route: DetailRoute = backStackEntry.toRoute()
            DetailScreen(itemId = route.itemId)
        }
    }
}
```

- Type-safe routes using Kotlin serializable objects (Compose Navigation 2.8+).
- Features define their own `NavGraphBuilder` extension functions — no feature knows about other features' routes.
- Deep links handled via the main nav host in `:app`.

---

## 4. Domain Layer (Use Cases)

### When to use

- Business logic is **complex** and would bloat the ViewModel.
- The same logic is **reused by multiple ViewModels**.

Do not create use cases for every simple operation — direct repository access from a ViewModel is fine for straightforward CRUD.

### Structure

**Naming convention:** `[Verb][Noun]UseCase`

```kotlin
class GetItemsUseCase @Inject constructor(
    private val itemRepository: ItemRepository,
    private val locationRepository: LocationRepository
) {
    suspend operator fun invoke(): Result<List<Item>> {
        val location = locationRepository.getCurrentLocation()
        return itemRepository.getItems(location)
    }
}
```

Rules:
- Main-safe — safe to call from the main thread.
- No mutable state. No lifecycle of their own.
- Use `withContext(Dispatchers.Default)` for CPU-intensive work; I/O stays in the data layer.

---

## 5. Data Layer

### Components

```
Repository
  ├── RemoteDataSource   (Retrofit / API)
  └── LocalDataSource    (Room DAO / DataStore)
```

Data sources are never accessed directly from outside the data layer.

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Repository | `[DataType]Repository` | `ItemRepository` |
| Remote data source | `[DataType]RemoteDataSource` | `ItemRemoteDataSource` |
| Local data source | `[DataType]LocalDataSource` | `ItemLocalDataSource` |
| API service | `[DataType]ApiService` | `ItemApiService` |

Do not name data sources after their implementation detail (`UserSharedPreferencesDataSource`) — name after the data type.

### Repository Pattern

```kotlin
class ItemRepository @Inject constructor(
    private val remoteDataSource: ItemRemoteDataSource,
    private val localDataSource: ItemLocalDataSource
) {
    // Room emits on every DB change — UI stays in sync automatically
    val items: Flow<List<Item>> = localDataSource.itemsFlow

    suspend fun syncItems(location: Location): Result<Unit> =
        remoteDataSource.fetchItems(location)
            .onSuccess { items -> localDataSource.saveItems(items) }
}
```

### Source of Truth

For offline-first features: **Room is the source of truth**. Sync writes to Room; UI observes Room via Flow. Never emit network data directly to the UI.

```
Network → Repository → Room (SSOT) → Flow → ViewModel → Compose UI
```

### Data Layer Rules

- Repositories expose `suspend` functions for one-shot ops, `Flow` for observable data.
- All data exposed from repositories is **immutable**.
- DAOs contain only SQL — no business logic, no mapping, no calculations.
- **Never** `fallbackToDestructiveMigration()` in production. Always explicit Room migrations.
- Data sources are never accessed from outside the data layer.

---

## 6. Module Graph & Enforcement

### Target dependency graph

```
:app
  └── :feature:[name]       ← Composables, ViewModel, Compose nav graph
        ├── :data:[name]    ← Repository + data sources
        │     └── :core:model
        │     └── :core:contracts
        ├── :core:base      ← Material3 theme, shared composables, nav contracts
        └── :core:[name]    ← Shared infrastructure (network, analytics, etc.)

:core:navigation  ← route definitions shared across features
:core:contracts   ← pure Kotlin interfaces, no Android SDK
:data:stubs       ← fake implementations for demo/test only
```

### Forbidden edges

| From | To | Reason |
|------|----|--------|
| `:data:*` | `:feature:*` | Data must not know features exist |
| `:data:*` | `:data:*` | Data modules are independent |
| `:feature:*` | `:feature:*` | Features are independent |
| `:core:contracts` | anything | Contracts are pure interfaces |

### Enforcement: Dependency Analysis Gradle Plugin

```kotlin
// root build.gradle.kts
plugins { alias(libs.plugins.dependency.analysis) }
```

Roll-out: run in warn mode first (`./gradlew buildHealth`), fix violations, then switch to fail mode and add to CI.

---

## 7. Cross-Module Communication via `:core:contracts`

Replace global event buses with typed interfaces in `:core:contracts` — pure Kotlin, no Android SDK.

```kotlin
// :core:contracts
interface DataEventEmitter {
    val dataChanges: Flow<DataChange>
}
```

Data modules implement. Feature modules depend on the interface. `:app` wires via Hilt. No module knows another's concrete class.

```kotlin
// :app
@Module @InstallIn(SingletonComponent::class)
object ContractsModule {
    @Provides
    fun provideDataEventEmitter(impl: DataEventEmitterImpl): DataEventEmitter = impl
}
```

---

## 8. Standalone Demo Modules

Each feature has a `:demo:[feature-name]` app module for isolated development and CI smoke testing.

```kotlin
// :demo:[feature]/build.gradle.kts
dependencies {
    implementation(project(":feature:[feature]"))
    implementation(project(":core:base"))
    implementation(project(":data:stubs"))
}
```

Entry point is a Compose `setContent {}` block in a single Activity — no Fragment, no XML layout.

If a feature cannot be isolated into a demo app, it has hidden coupling — find and fix it.

---

## 9. Dependency Injection (Hilt)

| Scope | Use for |
|-------|---------|
| `@Singleton` | App-lifetime: repositories, network client, database |
| `@ViewModelScoped` | ViewModel-bound dependencies |
| `@ActivityScoped` | Activity-lifetime dependencies |

**Application-scoped coroutine scope:**

```kotlin
@Module @InstallIn(SingletonComponent::class)
object CoroutinesModule {
    @Provides @Singleton @ApplicationScope
    fun provideApplicationScope(): CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Default)
}
```

Rules:
- No manual singletons (`@Volatile INSTANCE`). Hilt only.
- No service locator. Constructor injection everywhere.
- Never raw `CoroutineScope(Dispatchers.*)` in repositories — use `@ApplicationScope`.

---

## 10. General Best Practices

- **Don't store data in app components.** The `Activity` is an entry point — it hosts the Compose hierarchy and nothing else.
- **Reduce Android class dependencies.** Only the UI layer touches `Context`. Everything below is pure Kotlin.
- **Expose as little as possible.** Keep module internals private. Public API is the minimum necessary.
- **Drive UI from data models.** Room is the persistent layer. UI observes it via Flow — it always has data, even offline.
- **Single Source of Truth per data type.** Only the owner mutates. Others observe.

---

## 11. Key References

- **Official guide:** https://developer.android.com/topic/architecture
- **Compose:** https://developer.android.com/develop/ui/compose/documentation
- **Compose Navigation:** https://developer.android.com/guide/navigation/design
- **State and UDF in Compose:** https://developer.android.com/develop/ui/compose/state
- **Now in Android (reference implementation):** https://github.com/android/nowinandroid
- **Dependency Analysis plugin:** https://github.com/autonomousapps/dependency-analysis-gradle-plugin
- **Universal principles:** `roles/dev/standards/ARCHITECTURE.md`
