# AGENT CODING RULES & ARCHITECTURAL GUIDELINES

You must strictly adhere to the following rules for ALL code generation, refactoring, and feature implementations in this Flutter Web Dashboard project.

> ⚠️ **MANDATORY CHECKPOINT:** Before starting any new feature, task, or refactoring step, you MUST re-read and validate your code against these guidelines to ensure zero regressions.

---

## 1. Localization & String Handling
- **NO HARDCODED STRINGS:** Never write raw strings directly in UI widgets, logic layers, or error messages (e.g., no `Text('Dashboard')` or `errorMessage = 'Failed'`).
- **Use Localization Files:** All user-facing text, error messages, placeholders, and labels MUST be added to and referenced from the app's localization files (e.g., `AppLocalizations.of(context)!` or `easy_localization` / `slang` syntax used in the project).

---

## 2. GoRouter & Provider Scoping
- **No In-View Providers:** NEVER declare `BlocProvider` inside the `build()` method of UI View classes, inside custom widgets, or at the top of page screens.
- **Route-Level Scope:** ALL `BlocProvider` instances MUST be provided strictly inside the `GoRoute.builder` mapping within the `app_router.dart` configuration file.
- **Pure Const Views:** UI View widgets must accept `const` constructors where possible, remaining completely agnostic of how their Cubit/Bloc was created or provided.
- **Provider Restrictions:**
  - STRICTLY NO `BlocProvider.value`.
  - STRICTLY NO `MultiBlocProvider`.

---

## 3. UI Performance, Minimal Rebuilds & When Predicates (CRITICAL)
- **Targeted Rebuilds Only:** Wrap ONLY the specific component or leaf widget that actually needs to re-render with `BlocBuilder` or `BlocSelector`.
- **Mandatory `buildWhen` Condition:** ALL `BlocBuilder` instances MUST explicitly define a `buildWhen` predicate to ensure the widget ONLY rebuilds when the relevant subset of state actually changes.
- **Mandatory `listenWhen` Condition:** ALL `BlocListener` instances MUST explicitly define a `listenWhen` predicate to prevent redundant side-effects.
- **No Global/Screen-Level Rebuilds:** NEVER wrap an entire Screen, Scaffold, Layout Shell, Sidebar, Navigation Bar, or Header inside a `BlocBuilder`.
- **Aggressive Const Usage:** Use `const` constructors aggressively across all UI widgets to prevent unnecessary paint cycles on rebuild.

---

## 4. State Management (Cubit & Enum Pattern)
- **Enum-Based States:** Use an `enum` to represent status (e.g., `enum RequestStatus { initial, loading, success, failure }`) instead of creating multiple state classes per feature.
- **Single State Class:** Each feature Cubit must have a single immutable State class holding the status enum, data properties, and optional localized failure objects/keys.
- **`copyWith` Pattern:** Always use `copyWith` to emit new state instances cleanly.

---

## 5. Single Responsibility & File Structure
- **One Class Per File:** Every file must contain EXACTLY ONE class (with standard exceptions for abstract interfaces or simple data models where tightly bound).
- **Strict File Separation:** Cubits, States, UI Widgets, Data Sources, Repositories, and DI Modules MUST reside in their own separate files.

---

## 6. Modular Clean Architecture & Decoupling
- **Layer Independence:** Domain, Data, and Presentation layers must remain completely decoupled.
- **Domain Purity:** Domain MUST NOT depend on Supabase, Flutter UI, or external SDKs.
- **Data Isolation:** Supabase SDK calls must live strictly inside DataSources.

---

## 7. Feature-Level Dependency Injection (GetIt)
- **Modular DI:** Every feature MUST have its own dedicated DI setup file (e.g., `auth_di.dart`, `products_di.dart`).
- **No Monolithic DI File:** Do not append individual feature dependencies to a global main DI container. Delegate to feature-level modules.

---

## 8. Execution Discipline
- **One Micro-Step at a Time:** Execute refactoring or creation ONE MICRO-STEP at a time to maintain context and code quality.
- **No Unsolicited Scope Changes:** Do not modify unrelated files or change project structure unless explicitly instructed.