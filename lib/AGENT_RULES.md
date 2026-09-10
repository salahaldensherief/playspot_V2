# AGENT CODING RULES & ARCHITECTURAL GUIDELINES (Mobile App)

You must strictly adhere to the following rules for ALL code generation, refactoring, and feature implementations in this **Flutter Mobile App** project (Flutter + Supabase, Clean Architecture, BLoC/Cubit).

> This project shares its architecture, domain/data-layer contracts, and naming conventions with a companion **Web Dashboard** repository (governed by its own, separate rules file). If you are ever unsure whether a decision here (a `Failure` type, an RPC contract, a caching strategy, a naming convention) should match the dashboard side, assume it should — the two repos are meant to stay in lockstep on everything except platform-specific `presentation/` widgets.

⚠️ **MANDATORY CHECKPOINT:** Before starting any new feature, task, or refactoring step, you MUST re-read and validate your code against these guidelines to ensure zero regressions, zero infinite loops, zero UI crashes, and strict architectural integrity.

---

## 1. Localization & String Handling
- **NO HARDCODED STRINGS:** Never write raw strings directly in UI widgets, logic layers, or error messages (e.g., no `Text('Home')` or `errorMessage = 'Failed'`).
- **Use Localization Files:** All user-facing text, error messages, placeholders, and labels MUST be added to and referenced from the app's localization files (e.g., `AppLocalizations.of(context)!` or `easy_localization` / `slang` syntax used in the project).
- **RTL/LTR Safety:** Never hardcode directional values (`left`, `right`, `EdgeInsets.only(left: ...)`). Always use directional-aware widgets/properties (`EdgeInsetsDirectional`, `Alignment.centerStart/End`, `Directionality`-aware icons) so the UI works correctly in both Arabic (RTL) and English (LTR).

## 2. GoRouter & Provider Scoping
- **No In-View Providers:** NEVER declare `BlocProvider` inside the `build()` method of UI View classes, inside custom widgets, or at the top of page screens.
- **Route-Level Scope:** ALL `BlocProvider` instances MUST be provided strictly inside the `GoRoute.builder` mapping within the `app_router.dart` configuration file.
- **Global / Shell Scoping:** Persistent Cubits (such as `AuthCubit`, `CartCubit`, `NotificationsCubit`) MUST be initialized at the `ShellRoute`/root level and accessed via `context.read<YourCubit>()` in sub-views. NEVER re-instantiate them across child routes.
- **No Side-Effects in Creation:** NEVER trigger API requests, async fetches, or side-effects inside the `create: (context) => ...` callback of a `BlocProvider`. Instantiation must be pure.
- **Pure Const Views:** UI View widgets must accept `const` constructors where possible, remaining completely agnostic of how their Cubit/Bloc was created or provided.
- **Provider Restrictions:**
  - **No `MultiBlocProvider` — Use the Shared `AppProviderScope` Helper:** Instead of `MultiBlocProvider` or manual nesting, all `ShellRoute`-level persistent Cubits MUST be composed via a single shared helper widget (e.g. `MultiBlocProviderScope` in `art_core/di/provider_scope.dart`) that internally folds a `List<BlocProvider>` into a nested tree. This keeps the *call site* flat (one widget, one list) while still avoiding the banned `MultiBlocProvider` API directly, and prevents ad-hoc pyramid nesting from being hand-written per screen.
  - **`BlocProvider.value` Exception — Overlays Only:** `BlocProvider.value` is permitted in exactly one case: making an already-provided Cubit available inside a `showDialog`, `showModalBottomSheet`, or other `Navigator` overlay builder, since these build a widget subtree outside the calling context's tree. Usage outside this exception remains strictly prohibited.
- **Route Guards:** Auth/role/onboarding-based route protection MUST be implemented via `GoRouter.redirect` at the router configuration level, NEVER via conditional checks scattered inside individual screens.
- **Deep Link Safety:** Any route reachable via a deep link or push-notification payload MUST validate its path parameters defensively (missing/invalid IDs) and redirect to a safe fallback screen instead of crashing.

## 3. UI Engineering & Mobile Platform Stability Rules (CRITICAL)
- **Zero Force-Unwrapping (`!` Ban):** NEVER use the bang operator `!` on entity/model properties inside widgets (e.g., avoid `state.overview!.startTime!`). Always provide explicit fallback values (e.g., `overview?.cashierName ?? 'N/A'`, `overview?.startTime != null ? DateFormat.jm().format(overview!.startTime!) : '--:--'`). This rule applies specifically to the **null-assertion operator** (`someNullable!`), not to boolean logical negation (`!someBool`), which remains unrestricted.
- **Loading & Skeleton Shimmers:** Never display empty blank screens while states are loading. Always show a dedicated lightweight shimmer/skeleton loader that respects the widget's exact dimensions.
- **Empty & Error UI States:** Every list or card collection MUST render a clean, localized empty-state placeholder or error fallback widget with an explicit retry action button.
- **Destructive Action Confirmation:** Any delete, deactivate, logout, or irreversible mutation MUST be gated behind a confirmation dialog using the shared `AppConfirmDialog` component. Never wire a destructive action directly to a button's `onPressed`.
- **SafeArea & Notch Handling:** Every top-level screen MUST be wrapped in `SafeArea` (or explicitly opt out with a documented reason) to avoid content clipping under notches, status bars, or gesture-navigation bars.
- **Minimum Touch Target Size:** Any tappable element (button, icon, list tile) MUST have a minimum hit area of 48x48 logical pixels, even if the visual icon is smaller — pad with `InkWell`/`GestureDetector` sizing, not just visual padding.
- **Responsive Layout Rules:** Every screen MUST adapt across at least two standardized device classes (`phone`, `tablet`/`foldable-unfolded`) using the same shared `Breakpoints`/`ResponsiveLayout` utility referenced in the Web Dashboard rules (Section 3). NEVER hardcode pixel-based conditionals directly inside feature screens. Any widget subtree that is expensive to rebuild and sits beneath a breakpoint- or orientation-driven `LayoutBuilder` (e.g. on foldable unfold/fold or rotation) MUST be wrapped in `RepaintBoundary`, for the same reason as the Web Dashboard's resize-performance rule.
- **Hardware Back Button Behavior:** On Android, every screen with unsaved changes or a multi-step flow MUST intercept the system back gesture/button via `PopScope` and show a confirmation or navigate to the correct previous step — never let the default back action silently discard state.
- **Pull-to-Refresh Convention:** Any scrollable list backed by a Cubit fetch MUST support pull-to-refresh (`RefreshIndicator`) as the primary manual-refresh mechanism, wired to the `forceRefresh: true` bypass from Rule 7.
- **Offline-First Priority:** Mobile users are far more likely to be on unstable networks. The Cache-First strategy (Rule 7) is NON-NEGOTIABLE for all mobile read screens — never ship a screen that shows a blank error state on a dropped connection when cached data exists.
- **Keyboard & Scroll Safety:** Any screen with text inputs MUST ensure the keyboard never obscures the focused field or action buttons — wrap forms in a scrollable view and verify `resizeToAvoidBottomInset` behavior on both iOS and Android.
- **Platform-Adaptive Feel:** Where the design system doesn't explicitly override it, respect platform conventions (e.g., iOS-style back swipe gesture must keep working; do not disable it globally to "simplify" navigation).

## 4. UI Performance, Minimal Rebuilds & When Predicates
- **Targeted Rebuilds Only:** Wrap ONLY the specific component or leaf widget that actually needs to re-render with `BlocBuilder` or `BlocSelector`.
- **Mandatory `buildWhen` Condition:** ALL `BlocBuilder` instances MUST explicitly define a `buildWhen` predicate to ensure the widget ONLY rebuilds when the relevant subset of state actually changes.
- **Mandatory `listenWhen` Condition:** ALL `BlocListener` instances MUST explicitly define a `listenWhen` predicate to prevent redundant side-effects.
- **NO AUTOMATIC RETRIES IN LISTENERS:** NEVER trigger automatic data re-fetching inside a `BlocListener` when a failure/error state is caught. Retries must strictly be user-initiated (e.g., via a "Try Again" button or pull-to-refresh) to prevent infinite re-render/retry loops.
- **No Global/Screen-Level Rebuilds:** NEVER wrap an entire Screen, Scaffold, Bottom Navigation Bar, or App Bar inside a `BlocBuilder`.
- **Aggressive Const Usage:** Use `const` constructors aggressively across all UI widgets to prevent unnecessary paint cycles on rebuild — this matters even more on lower-end mobile devices than on desktop browsers.
- **Debounce Reactive Inputs:** Any search field, filter, or input that triggers a Cubit event on every keystroke MUST be debounced (e.g., 300–500ms) using a shared debouncer utility to prevent excessive API calls/rebuilds and battery drain.
- **List Rendering Efficiency:** Long lists MUST use `ListView.builder`/`SliverList` (lazy building), never `ListView(children: [...])` with a manually mapped list, to avoid building offscreen items and jank on mid-range devices.

## 5. State Management, Value Equality & Equatable
- **Enum-Based States:** Use an enum to represent status (e.g., `enum RequestStatus { initial, loading, success, failure }`) instead of creating multiple state classes per feature.
- **Single State Class:** Each feature Cubit must have a single immutable State class holding the status enum, data properties, and optional localized failure objects/keys.
- **Mandatory Equatable on All States and Models:** ALL State classes, Entities, and Models MUST extend `Equatable` and implement `List<Object?> get props` accurately. Emitting a state with identical values must NOT trigger listeners or rebuilds.
- **`copyWith` Pattern:** Always use `copyWith` to emit new state instances cleanly.
- **Stream & Controller Disposal:** Any `StreamSubscription`, `TextEditingController`, `ScrollController`, `AnimationController`, or Supabase Realtime channel subscription created inside a Cubit/Widget MUST be explicitly cancelled/disposed in `close()` (Cubit) or `dispose()` (Widget). No exceptions — this is critical on mobile where screens are pushed/popped constantly and leaks compound quickly.
- **Idempotent Stream Subscriptions (5.1):** Any Cubit method that starts a realtime subscription (`startWatching...`, `watch...`) MUST: (1) cancel any existing `StreamSubscription` held by the Cubit before creating a new one, regardless of whether the method is being called for the first time or re-invoked; (2) guard against redundant re-invocation with identical parameters (e.g. store the last id/params passed and skip re-subscribing if unchanged); (3) treat the Cubit itself, not the calling widget, as the single source of truth for subscription lifecycle. This applies to continuous local streams (e.g. `Geolocator` position streams) exactly as it applies to Realtime subscriptions.
- **App Lifecycle Awareness:** Cubits/services holding active subscriptions (Realtime channels, location streams, timers) MUST respond to `AppLifecycleState` changes — pause/detach on `paused`/`inactive` and resume on `resumed`, to avoid draining battery or crashing in the background.

## 6. Clean Architecture Purity & Directory Scaffolding (Flat Presentation)
- **No Duplicate Data Sources / Repositories:** NEVER create duplicate files or competing folders (e.g., do NOT create both `data_source` and `data_sources`, or `repos` and `repositories`).
- **Standard Feature Scaffolding:**

```
feature_name/
├── data/
│   ├── datasources/                # Single Remote & Local Data Source files (including caching layers)
│   ├── models/                     # Data transfer objects extending Entities
│   └── repositories/               # Concrete Repository implementations (*_repository_impl.dart)
├── domain/
│   ├── entities/                   # Pure business models extending Equatable
│   ├── repositories/               # Abstract repository interfaces (*_repository.dart)
│   └── usecases/                   # Individual callable use case classes
└── presentation/
    ├── feature_screen.dart         # Direct Screen / View file (NO screens/ subfolder)
    ├── feature_cubit.dart          # Direct Cubit file (NO cubit/ subfolder)
    ├── feature_state.dart          # Direct State file (NO cubit/ subfolder)
    └── widgets/                    # Dedicated folder strictly for reusable private UI widgets
```

- **Strict Entity Location:** Entities MUST reside in `domain/entities/`, NEVER inside `data/entities/`.
- **One Class Per File:** Every file must contain EXACTLY ONE class.

## 7. Supabase Queries, Database Safety & Caching Strategies
- **No Nested / Recursive Table Joins:** In Remote Data Sources, do NOT perform joins that traverse recursive foreign keys (e.g., avoid `.select('*, profiles(full_name)')` if `profiles` has circular relations). Perform flat, indexed selects or delegate to dedicated RPC functions.
- **Column Verification:** Always verify exact column names before executing queries (e.g., do NOT guess `user_id` when the schema uses `cashier_id` or `staff_user_id`).
- **Safe RPC Over Complex Selects:** For aggregate stats, profile overviews, or complex multi-table checks, always call dedicated `SECURITY DEFINER` Postgres functions with `SET search_path = public` and `SET row_security = off` to eliminate `PostgreSQL 54001: stack depth limit exceeded` recursion errors.
- **Location Updates Isolation:** Functions that update hardware/device state (e.g., GPS location, device info, push token) MUST be called exactly once during bootstrap/login with an explicit execution flag. NEVER trigger updates inside `build()` methods or reactive listeners. This rule governs writes of device location to the backend (e.g. updating a stored `last_known_location` column) — it does NOT prohibit a continuous local `Geolocator`/platform-location stream used purely for client-side UI purposes (e.g. distance sorting). Continuous local location streams remain subject to the standard subscription hygiene rules in Section 5 (cancel on `dispose()`/`close()`, pause on `AppLifecycleState.paused`).
- **RLS Awareness:** Never assume a table is protected — every new Supabase table accessed from the client MUST have Row Level Security policies verified/documented before the data source is written. Never bypass RLS from the client by using the service role key.
- **Pagination for Large Datasets:** Any list-returning query expected to grow beyond ~50 rows (orders, notifications, history) MUST use `.range()`-based pagination or an infinite-scroll cursor in the data source. NEVER fetch an entire table with an unbounded `select()`.

### 🗄️ Caching & Invalidation Rules (Cache-First Strategy)
- **Cache-First Implementation:** For heavy or frequently accessed read operations (e.g., user profile, home feed, configurations), repositories MUST use a Cache-First strategy via Local Data Sources (SharedPreferences / Hive / Isar). Instantly emit local cache for zero-latency UI rendering, then fetch fresh data from Supabase in the background, update the cache, and emit the fresh state.
- **Cache Emission Must Not Regress Realtime-Updated State (7.1):** If a feature combines Cache-First reads with an active Realtime subscription (Section 5) for the same data, the repository/Cubit MUST track a last-updated timestamp or version marker and discard any cache-sourced emission that is older than the most recently applied Realtime update for that entity.
- **Write-Through & Invalidation on Mutate:** Whenever a mutation, update, or write operation succeeds (e.g., `updateUserProfile`, `updateCartItem`), the repository must immediately update or clear/invalidate the corresponding local cache keys to prevent displaying stale data.
- **Session & Auth Cleanup:** Always clear relevant local cache keys or invoke local storage resets upon user Logout to prevent data leakage between different accounts on a shared/reused device.
- **Manual Refresh Bypass:** Provide a `forceRefresh: true` flag or equivalent mechanism in repository fetch methods to completely bypass local caching when pull-to-refresh is triggered.
- **Realtime Channel Hygiene:** Any Supabase Realtime channel (`.channel(...)`) subscribed to inside a repository/data source MUST be unsubscribed/removed (`supabase.removeChannel`) when the owning Cubit closes, to prevent duplicate event listeners and memory leaks. Ownership is layered, not duplicated: the **Repository/Datasource** owns the Supabase `RealtimeChannel` and is solely responsible for `supabase.removeChannel()`. The **Cubit** owns the `StreamSubscription` it created by listening to the Repository's stream, and is solely responsible for cancelling *that* subscription (see Section 5). Neither layer calls the other's cleanup method directly.

## 8. Feature-Level Dependency Injection (GetIt)
- **Modular DI:** Every feature MUST have its own dedicated DI setup file (e.g., `auth_di.dart`, `cart_di.dart`).
- **Explicit Type Registration:** Always register dependencies via their abstract interfaces (e.g., `sl.registerLazySingleton<CartRepository>(() => CartRepositoryImpl(sl()))`).
- **No Dead Registrations:** When removing or refactoring duplicate data sources/repositories, immediately clean up and sync the feature DI file and `injection_container.dart`.

## 9. Execution Discipline
- **One Micro-Step at a Time:** Execute refactoring or creation ONE MICRO-STEP at a time to maintain context and code quality.
- **Verify Existing Code First:** Before creating any new file, inspect existing directories to prevent duplicating classes that already exist under slightly different names.
- **No Unsolicited Scope Changes:** Do not modify unrelated files or change project structure unless explicitly instructed.

## 10. Single Component Architecture & Custom Component Reuse (MANDATORY)
- **SINGLE STANDARDIZED BUTTON COMPONENT:** ALL buttons across the entire codebase MUST strictly use `AppButton` (`lib/art_core/widgets/app_button.dart`). Direct usage of raw Flutter buttons (`ElevatedButton`, `OutlinedButton`, `TextButton`) or duplicate custom button implementations in feature modules is strictly prohibited. `AppButton` supports all variants (`primary`, `gradient`, `outlined`, `danger`, `text`), icons, loading states, and custom styling.
- **CUSTOM COMPONENT REUSE FOR REPEATED UI:** Any UI widget, card, list tile, input field, status badge, dialog, or bottom sheet that appears in more than one place MUST be created as a custom reusable widget component under `lib/art_core/widgets/` or feature-specific `widgets/`. Re-writing or duplicating identical UI structures across screens is strictly forbidden.
- **Design Tokens Only:** Colors, spacing, radii, font sizes, and shadows MUST always come from the shared theme/design-tokens file (e.g., `AppColors`, `AppSpacing`, `AppTextStyles`). Raw hex codes (`Color(0xFF...)`), magic numbers (`SizedBox(height: 17)`), or inline `TextStyle(fontSize: 14)` are strictly forbidden inside feature code.

## 11. Error Handling & Result Pattern (MANDATORY)
- **Unified Failure Type:** Define a single sealed/abstract `Failure` hierarchy in `core/errors/` (e.g., `ServerFailure`, `CacheFailure`, `NetworkFailure`, `ValidationFailure`). NEVER throw raw `Exception` or `String` errors out of a Repository or Usecase.
- **Either/Result Contract:** Every Repository method and Usecase MUST return `Either<Failure, T>` (via `dartz` or `fpdart`, whichever is already used in the project — verify before adding a new dependency). Cubits must never catch raw exceptions from a repository call; they only pattern-match on `Left`/`Right`.
- **Exception-to-Failure Mapping:** Data sources are the ONLY layer allowed to catch raw exceptions (`PostgrestException`, `SocketException`, `AuthException`, etc.) and must map them to the appropriate `Failure` subtype before they cross into the Repository layer.
- **Localized Failure Messages:** Every `Failure` must carry a localization key (not a raw English string) so the presentation layer can render it via the localization system from Rule 1.

## 12. Logging & Debugging Discipline
- **No `print()` in Production Code:** NEVER use `print()`, `debugPrint()` for permanent logging, or leftover `// TODO: remove` debug statements. Use the project's shared `AppLogger` (wrapping the `logger` package or similar) with proper log levels (`info`, `warning`, `error`).
- **No Sensitive Data in Logs:** Never log tokens, passwords, full user objects, device identifiers, or raw Supabase auth sessions, even at debug level.
- **Clean Before Commit:** Any temporary debug logging added during a task MUST be removed before considering the task complete.

## 13. Testing Requirements
- **Usecases Must Be Testable & Tested:** Every Usecase MUST have at least one corresponding unit test covering the success path and at least one failure path, using mocked Repository interfaces (`mocktail`/`mockito`).
- **Cubit Testing:** Every Cubit MUST have `bloc_test` coverage for its primary state transitions (initial → loading → success/failure), using a mocked Usecase layer.
- **No Live Network Calls in Tests:** Tests MUST NEVER hit the real Supabase project. All data sources are mocked at the Repository or Datasource boundary.
- **Widget Tests for Shared Components:** Any component added under `art_core/widgets/` (per Rule 10) that is reused in 3+ places MUST include a basic widget test verifying it renders without exceptions across its documented variants.
- **Responsive Device-Class Coverage:** Any screen implementing the mandatory responsive layout across device classes (Section 3) MUST have at least one widget/golden test per device class (`phone`, `tablet`) verifying the correct branch renders without exceptions.

## 14. Security & Configuration
- **No Hardcoded Secrets:** Supabase URL, anon key, or any API key/secret MUST NEVER be hardcoded directly in Dart files. They must be injected via `--dart-define`, a `.env` file (excluded from version control), or a build-time config class populated from environment variables.
- **Client Never Uses Service Role Key:** The Supabase service role key must never appear anywhere in client-side (Flutter) code, under any circumstance — only the anon/public key is allowed on the client, protected by RLS.
- **Input Validation Before Mutation:** Any form or input feeding a Supabase write MUST be validated on the client (required fields, formats, ranges) before the mutation call is dispatched — never rely on the database to be the only validation layer.
- **Secure Local Storage for Sensitive Data:** Auth tokens, refresh tokens, and any PII cached locally MUST use `flutter_secure_storage` (Keychain/Keystore-backed), NEVER plain `SharedPreferences`, which is unencrypted on-device storage.
- **Biometric/PIN Gate (if applicable):** If the app exposes sensitive actions (payments, account changes), gate them behind the device's biometric/PIN re-authentication where the feature spec calls for it — never assume a logged-in session alone is sufficient.

## 15. Naming Conventions
- **Files:** `snake_case.dart` matching the primary class name (e.g., `cart_repository_impl.dart` → `CartRepositoryImpl`).
- **Classes:** `PascalCase`, suffixed by role — `*RepositoryImpl`, `*RemoteDataSource`, `*LocalDataSource`, `*Usecase`, `*Cubit`, `*State`.
- **Usecase Naming:** Verb-first, feature-scoped (e.g., `GetUserProfile`, `UpdateCartItem`) — never generic names like `Handler` or `Manager`.
- **No Ambiguous/Abbreviated Names:** Avoid unclear shorthand (`mgr`, `tmp`, `data2`). Names must describe intent, not implementation detail.

## 16. Problem Diagnosis & Root Cause Verification Before Execution (MANDATORY)
- **MANDATORY DIAGNOSIS FIRST:** Before attempting any bug fix, code modification, or refactoring, you MUST first perform a complete diagnostic analysis to confirm whether the root cause originates from the **Frontend** (Flutter UI, BLoC state, data models, router) or the **Backend** (Supabase DB schema, RLS policies, RPC functions, network/server responses).
- **No Immediate Fixes Without Evidence:** NEVER jump directly into modifying code or writing fixes upon receiving an error report. Always trace the logs, check network/database responses, and verify the exact failure source first.
- **Clear Root Cause Explanation:** Present your diagnostic findings clearly to the user, explaining whether the issue is Frontend or Backend, before applying or proposing any solution.

---

**Priority Note:** If any rule above ever conflicts with the Directory Scaffolding in Section 6, Section 6 wins — the folder structure must never be altered to accommodate a new rule; new rules must fit inside the existing structure instead. This scaffolding must stay identical to the one used in the Web Dashboard repo — only the `presentation/` layer's widget implementations are allowed to differ between the two.