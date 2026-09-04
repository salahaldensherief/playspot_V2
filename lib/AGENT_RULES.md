AGENT CODING RULES & ARCHITECTURAL GUIDELINES
You must strictly adhere to the following rules for ALL code generation, refactoring, and feature implementations in this Flutter Web Dashboard project.

⚠️ MANDATORY CHECKPOINT: Before starting any new feature, task, or refactoring step, you MUST re-read and validate your code against these guidelines to ensure zero regressions, zero infinite loops, zero UI crashes, and strict architectural integrity.

1. Localization & String Handling
   NO HARDCODED STRINGS: Never write raw strings directly in UI widgets, logic layers, or error messages (e.g., no Text('Dashboard') or errorMessage = 'Failed').

Use Localization Files: All user-facing text, error messages, placeholders, and labels MUST be added to and referenced from the app's localization files (e.g., AppLocalizations.of(context)! or easy_localization / slang syntax used in the project).

2. GoRouter & Provider Scoping
   No In-View Providers: NEVER declare BlocProvider inside the build() method of UI View classes, inside custom widgets, or at the top of page screens.

Route-Level Scope: ALL BlocProvider instances MUST be provided strictly inside the GoRoute.builder mapping within the app_router.dart configuration file.

Global / Shell Scoping: Persistent Cubits (such as ShiftCubit, LoungeStatsCubit, DashboardCubit) MUST be initialized at the ShellRoute level and accessed via context.read<YourCubit>() in sub-views. NEVER re-instantiate them across child routes.

No Side-Effects in Creation: NEVER trigger API requests, async fetches, or side-effects inside the create: (context) => ... callback of a BlocProvider. Instantiation must be pure.

Pure Const Views: UI View widgets must accept const constructors where possible, remaining completely agnostic of how their Cubit/Bloc was created or provided.

Provider Restrictions:

STRICTLY NO BlocProvider.value.

STRICTLY NO MultiBlocProvider.

3. UI Engineering & Web Stability Rules (CRITICAL)
   Zero Force-Unwrapping (! Ban): NEVER use the bang operator ! on entity/model properties inside widgets (e.g., avoid state.overview!.startTime!). Always provide explicit fallback values (e.g., overview?.cashierName ?? 'N/A', overview?.startTime != null ? DateFormat.jm().format(overview!.startTime!) : '--:--').

Web Layout & Hit-Testing Safety: Never perform gesture handling or size queries during unconstrained layout passes. Ensure all parent containers inside Web Dashboards have bounded constraints or wrapped inside Expanded / Flexible to prevent Cannot hit test a render box that has never been laid out.

Loading & Skeleton Shimmers: Never display empty blank screens while states are loading. Always show a dedicated lightweight shimmer/skeleton loader that respects the widget's exact dimensions.

Empty & Error UI States: Every list, table, or card collection MUST render a clean, localized empty-state placeholder or error fallback widget with an explicit retry action button.

CanvasKit Context Loss Protection: Do not trigger continuous micro-animations or unbounded canvas repaints during data fetches to avoid browser WebGL crashes.

4. UI Performance, Minimal Rebuilds & When Predicates
   Targeted Rebuilds Only: Wrap ONLY the specific component or leaf widget that actually needs to re-render with BlocBuilder or BlocSelector.

Mandatory buildWhen Condition: ALL BlocBuilder instances MUST explicitly define a buildWhen predicate to ensure the widget ONLY rebuilds when the relevant subset of state actually changes.

Mandatory listenWhen Condition: ALL BlocListener instances MUST explicitly define a listenWhen predicate to prevent redundant side-effects.

NO AUTOMATIC RETRIES IN LISTENERS: NEVER trigger automatic data re-fetching inside a BlocListener when a failure / error state is caught. Retries must strictly be user-initiated (e.g., via a "Try Again" button) to prevent infinite re-render / retry loops.

No Global/Screen-Level Rebuilds: NEVER wrap an entire Screen, Scaffold, Layout Shell, Sidebar, Navigation Bar, or Header inside a BlocBuilder.

Aggressive Const Usage: Use const constructors aggressively across all UI widgets to prevent unnecessary paint cycles on rebuild.

5. State Management, Value Equality & Equatable
   Enum-Based States: Use an enum to represent status (e.g., enum RequestStatus { initial, loading, success, failure }) instead of creating multiple state classes per feature.

Single State Class: Each feature Cubit must have a single immutable State class holding the status enum, data properties, and optional localized failure objects/keys.

Mandatory Equatable on All States and Models: ALL State classes, Entities, and Models MUST extend Equatable and implement List<Object?> get props accurately. Emitting a state with identical values must NOT trigger listeners or rebuilds.

copyWith Pattern: Always use copyWith to emit new state instances cleanly.

6. Clean Architecture Purity & Directory Scaffolding (Flat Presentation)
   No Duplicate Data Sources / Repositories: NEVER create duplicate files or competing folders (e.g., do NOT create both data_source and data_sources, or repos and repositories).

Standard Feature Scaffolding:

Plaintext
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
Strict Entity Location: Entities MUST reside in domain/entities/, NEVER inside data/entities/.

One Class Per File: Every file must contain EXACTLY ONE class.

7. Supabase Queries, Database Safety & Caching Strategies
   No Nested / Recursive Table Joins: In Remote Data Sources, do NOT perform joins that traverse recursive foreign keys (e.g., avoid .select('*, profiles(full_name)') if profiles has circular relations). Perform flat, indexed selects or delegate to dedicated RPC functions.

Column Verification: Always verify exact column names before executing queries (e.g., do NOT guess user_id when the schema uses cashier_id or staff_user_id).

Safe RPC Over Complex Selects: For aggregate stats, dashboard overviews, or complex multi-table checks, always call dedicated SECURITY DEFINER Postgres functions with SET search_path = public and SET row_security = off to eliminate PostgreSQL 54001: stack depth limit exceeded recursion errors.

Location Updates Isolation: Functions that update hardware/device state (e.g., GPS location, device info) MUST be called exactly once during bootstrap/login with an explicit execution flag. NEVER trigger updates inside build() methods or reactive listeners.

🗄️ Caching & Invalidation Rules (Cache-First Strategy)
Cache-First Implementation: For heavy or frequently accessed read operations (e.g., lounge profiles, menus, configurations), repositories MUST use a Cache-First strategy via Local Data Sources (SharedPreferences / Hive / Isar). Instantly emit local cache for zero-latency UI rendering, then fetch fresh data from Supabase in the background, update the cache, and emit the fresh state.

Write-Through & Invalidation on Mutate: Whenever a mutation, update, or write operation succeeds (e.g., updateLoungeProfile, updateMenuItem), the repository must immediately update or clear/invalidate the corresponding local cache keys to prevent displaying stale data.

Session & Auth Cleanup: Always clear relevant local cache keys or invoke local storage resets upon user Logout to prevent data leakage between different admin sessions.

Manual Refresh Bypass: Provide a forceRefresh: true flag or equivalent mechanism in repository fetch methods to completely bypass local caching when a manual sync/refresh is triggered.

8. Feature-Level Dependency Injection (GetIt)
   Modular DI: Every feature MUST have its own dedicated DI setup file (e.g., auth_di.dart, shifts_di.dart).

Explicit Type Registration: Always register dependencies via their abstract interfaces (e.g., sl.registerLazySingleton<ShiftRepository>(() => ShiftRepositoryImpl(sl()))).

No Dead Registrations: When removing or refactoring duplicate data sources/repositories, immediately clean up and sync the feature DI file and injection_container.dart.

9. Execution Discipline
   One Micro-Step at a Time: Execute refactoring or creation ONE MICRO-STEP at a time to maintain context and code quality.

Verify Existing Code First: Before creating any new file, inspect existing directories to prevent duplicating classes that already exist under slightly different names.

No Unsolicited Scope Changes: Do not modify unrelated files or change project structure unless explicitly instructed.