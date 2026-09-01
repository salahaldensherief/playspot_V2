# AGENT CODING RULES & ARCHITECTURAL GUIDELINES (WEB & MOBILE)

You must strictly adhere to the following rules for ALL code generation, refactoring, and feature implementations across both the Flutter Web Dashboard and Mobile Application.

> ⚠️ **MANDATORY CHECKPOINT:** Before starting any new feature, task, or refactoring step, you MUST re-read and validate your code against these guidelines to ensure zero regressions, zero infinite loops, zero UI crashes, and strict architectural integrity.

---

## 1. Localization & String Handling
- **NO HARDCODED STRINGS:** Never write raw strings directly in UI widgets, logic layers, or error messages (e.g., no `Text('Dashboard')` or `errorMessage = 'Failed'`).
- **Use Localization Files:** All user-facing text, error messages, placeholders, and labels MUST be added to and referenced from the app's localization setup (`easy_localization`).

---

## 2. GoRouter & Provider Scoping
- **No In-View Providers:** NEVER declare `BlocProvider` inside the `build()` method of UI View classes, inside custom widgets, or at the top of page screens.
- **Route-Level Scope:** ALL `BlocProvider` instances MUST be provided strictly inside the `GoRoute.builder` mapping within the routing configuration.
- **Global / Shell Scoping:** Persistent Cubits (such as `ShiftCubit`, `LoungeStatsCubit`, `DashboardCubit`, `NotificationsCubit`) MUST be initialized at the `ShellRoute` level and accessed via `context.read<YourCubit>()` in sub-views. NEVER re-instantiate them across child routes.
- **No Side-Effects in Creation:** NEVER trigger API requests, async fetches, or side-effects inside the `create: (context) => ...` callback of a `BlocProvider`. Instantiation must be pure.
- **Pure Const Views:** UI View widgets must accept `const` constructors where possible, remaining completely agnostic of how their Cubit/Bloc was created or provided.
- **Provider Restrictions:**
    - STRICTLY NO `BlocProvider.value`.
    - STRICTLY NO `MultiBlocProvider`.

---

## 3. UI Engineering, Feedback & Stability Rules
- **Zero Force-Unwrapping (`!` Ban):** NEVER use the bang operator `!` on entity/model properties inside widgets. Always provide explicit fallback values (e.g., `overview?.cashierName ?? 'N/A'`).
- **Mobile HUD Toasts vs. SnackBars:**
    - In the **Mobile App**, STRICTLY AVOID default `ScaffoldMessenger.of(context).showSnackBar`.
    - Use the custom `GameHudToast.show(...)` overlay for all feedback (success, errors, voucher alerts).
    - Triggers must reside exclusively inside `BlocListener` callbacks or button `onTap` handlers—NEVER in `build()`.
- **Web Layout & Constraints:** Parent containers inside Web Dashboards must have bounded constraints or be wrapped in `Expanded` / `Flexible` to prevent layout engine crashes.
- **Loading & Skeleton Shimmers:** Never display blank screens while loading. Render lightweight skeleton loaders matching widget dimensions.
- **Empty & Error UI States:** Every list or table MUST render a localized empty-state placeholder or error fallback with a manual retry button.

---

## 4. UI Performance, Minimal Rebuilds & When Predicates
- **Targeted Rebuilds Only:** Wrap ONLY the specific component or leaf widget that needs to re-render with `BlocBuilder` or `BlocSelector`.
- **Mandatory `buildWhen` Condition:** ALL `BlocBuilder` instances MUST explicitly define a `buildWhen` predicate.
- **Mandatory `listenWhen` Condition:** ALL `BlocListener` instances MUST explicitly define a `listenWhen` predicate.
- **NO AUTOMATIC RETRIES IN LISTENERS:** NEVER trigger automatic data re-fetching inside a `BlocListener` on error. Retries must strictly be user-initiated to prevent infinite loops.
- **No Global/Screen-Level Rebuilds:** NEVER wrap an entire Screen, Scaffold, Layout Shell, Sidebar, Navigation Bar, or Header inside a `BlocBuilder`.
- **Aggressive Const Usage:** Use `const` constructors aggressively across all UI widgets.

---

## 5. State Management, Value Equality & Handler Discipline
- **Enum-Based States:** Use enums to represent status (e.g., `enum RequestStatus { initial, loading, success, failure }`).
- **Single State Class:** Each feature Cubit must have a single immutable State class implementing `Equatable`.
- **NO SILENT HANDLERS:** NEVER write stubbed success/failure handlers like `(_) => null` or `(failure) => null`. Always emit an updated state or localized error message.
- **Optimistic UI with Rollback:** For instant actions (e.g., `swapRoom`, marking notifications as read), update the local state immediately before network completion. Always implement a safe rollback mechanism if the network call fails.
- **`copyWith` Pattern:** Always use `copyWith` to emit new state instances cleanly.

---

## 6. Clean Architecture Purity & Directory Scaffolding
- **Standard Feature Scaffolding:**
  ```text
  feature_name/
  ├── data/
  │   ├── datasources/
  │   ├── models/
  │   └── repositories/
  ├── domain/
  │   ├── entities/
  │   ├── repositories/
  │   └── usecases/
  └── presentation/
      ├── feature_screen.dart
      ├── feature_cubit.dart
      ├── feature_state.dart
      └── widgets/