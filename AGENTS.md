# PlaySpot Mobile: agent engineering rules

Read this file before changing code. It is the primary agent guidance for this repository. `AGENTS_RULES.md` contains additional conventions; where it conflicts with this file, follow this file. User instructions and verified product requirements take precedence over both.

## Understand the change

- Trace the real flow before editing: widget -> Cubit/state -> use case or repository -> data source -> Supabase RPC/table -> RLS -> response. Some existing features do not use every layer; follow their actual boundaries.
- Find the existing contract, tests, and related Dashboard behavior. State the invariant and choose the layer that owns it. Fix a defect at its root cause rather than hiding it in the UI.
- Make focused changes. Do not refactor unrelated features or silently change public models, RPC payloads, or database behavior.

## SOLID and clean architecture

- **Single responsibility:** Keep widgets responsible for presentation, Cubits for state and orchestration, use cases/domain services for application rules, repositories for domain-facing data contracts, and data sources for external I/O and parsing. Split a class when it has independent reasons to change, not merely because it crosses a line count.
- **Open/closed:** Extend behavior through a strategy or policy when there are real interchangeable rules (for example, distinct slot or pricing policies). For a single simple case, prefer a clear function over a new abstraction.
- **Liskov substitution:** Implementations must honor repository contracts, including errors, nullability, ownership, and side effects. Do not make a subtype silently weaken an invariant.
- **Interface segregation:** Expose only operations a consumer needs. Avoid giant repository interfaces and placeholder methods that throw for unsupported operations.
- **Dependency inversion:** Domain rules depend on contracts, not Supabase, Flutter widgets, or concrete data sources. Wire implementations through the existing GetIt modules. Do not add an interface for a pure helper with one implementation unless a boundary or test seam calls for it.
- Keep dependencies pointing inward where the feature already uses `presentation / domain / data`. Do not import data models into domain business rules. Map backend DTOs at the data boundary. Do not build ceremonial layers in simple existing paths.
- Use a design pattern only when it solves a concrete variation or lifecycle problem. Prefer the current Cubit, repository, strategy, and dependency injection conventions; explain any new pattern in the PR.

## Server authority and cross-client contracts

- Supabase owns booking conflicts, hold validity, checkout prices, payments, permissions, inventory, loyalty, and lifecycle transitions. Flutter availability and totals are previews. Never trust client-submitted financial or authorization values.
- Keep Mobile and Dashboard aligned with the same server contract; their presentation may differ. Review RLS, grants, role scope, concurrency, idempotency, and state transitions when changing an RPC or schema. Never put a service-role key in a client.
- Prefer invoker privileges and RLS. Use `SECURITY DEFINER` only when justified, with explicit actor/resource authorization, a safe `search_path`, and narrow execute grants. Never force it merely to satisfy a folder or architecture rule.
- Treat production data as live. Test destructive and concurrency scenarios in staging or with isolated safe records; do not replay old migrations against production.

## Clean code and verification

- Use names that express business meaning, small cohesive functions, guard clauses, immutable state, and localized user-facing strings. Keep Arabic/English and RTL/LTR behavior working. Remove dead paths after verifying callers.
- Reuse existing logic when it represents the same invariant. Avoid premature utilities, rigid file/line caps, universal one-class-per-file rules, and abstractions that add indirection without benefit.
- Handle loading, empty, error, retry, cancellation, and repeated taps. Cancel subscriptions and ignore stale async results. Keep errors visible and actionable.
- For a bug: reproduce -> identify root cause -> fix in the owning layer -> add a regression test -> verify. For new behavior, test the important business invariant and authorization/concurrency where relevant. Unit, widget, integration, and RLS tests are all allowed; do not prohibit network-backed tests when an isolated environment exists.
- Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-fatal-infos`, and relevant `flutter test` suites when available. Report exactly what ran and what could not run. Keep changes in a focused PR and wait for CI before claiming verification.
