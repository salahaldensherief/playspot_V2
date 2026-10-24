# PlaySpot Mobile: agent engineering guide

This is the single source of agent guidance for the Flutter mobile repository. User instructions and verified product requirements take precedence. Apply these rules to code you touch; improve unrelated legacy code in focused follow-up changes.

Current integration, research, the read-only financial contract verdict and proposed local architecture are recorded in `docs/PLAYSPOT_CURRENT_BASELINE_20261023.md`, `docs/audits/PLAYSPOT_MARKET_CAPABILITY_REVIEW_20261024.md`, `docs/audits/PLAYSPOT_FINANCIAL_CONTRACT_VERIFICATION_20261024.md` and `docs/audits/PLAYSPOT_LOCAL_OPERATIONS_ARCHITECTURE_20261024.md`. Read the merged `docs/PLAYSPOT_SYSTEM_ATLAS.md` for cross-stack context, then check current `dev`, PR state, source and contracts before acting on these dated snapshots. The inspected deployed completion function misclassifies partial collections; keep financial integration Draft until a representative-schema fix and verification pass.

## Diagnose and respect the existing contract

- Trace the real flow before editing: widget → Cubit/state → use case or repository → data source → Supabase RPC/table → RLS → response. Follow the layers that actually exist for the feature.
- Reproduce bugs and identify whether the cause is mobile, Dashboard, or backend. Inspect existing tests and the Dashboard's use of shared server contracts before changing them. State the invariant and fix it in the owning layer.
- Keep public models, RPC payloads, database behavior, routes, and cache semantics stable unless the task requires a coordinated change. Verify route names and parameters before adding navigation.
- Make focused changes. Check for an existing implementation before creating a new helper, model, file, or dependency.

## Architecture and reusable code

- Widgets present data and capture input; Cubits manage state and orchestration; domain services or use cases hold business rules; repositories expose domain facing contracts; data sources handle I/O and parsing. Map backend DTOs at the data boundary.
- Keep dependencies pointing inward where the feature already uses `presentation / domain / data`. Register implementations through the existing GetIt modules and remove dead registrations.
- Prefer small cohesive functions, guard clauses, immutable state, descriptive names, and explicit result/error types. A class should have one clear reason to change. Split code when independent responsibilities or complex control flow warrant it; do not split it to satisfy a file or line count.
- Reuse a component or helper when it represents the same behavior or invariant. Do not create abstractions for a single simple case, duplicate implementations, giant interfaces, or placeholder methods. Use strategies only for real interchangeable rules.
- Preserve repository contracts for errors, nullability, ownership, and side effects. Avoid `Either<String, T>` when a `Failure` type exists. Do not leak raw Supabase errors through domain APIs.
- Use `snake_case.dart`, Dart `PascalCase` types and `camelCase` members. Declare directly imported packages in `pubspec.yaml` with the project's version convention.

## Server authority and security

- Supabase owns booking conflicts, hold validity, prices, payments, permissions, inventory, loyalty, and lifecycle transitions. Client availability and totals are previews. Validate input on the client for usability and enforce the rule again on the server.
- Keep Mobile and Dashboard aligned on the same server contract. Review RLS, grants, role scope, concurrency, idempotency, and transitions when changing an RPC or schema. Never put a service role key or other secret in client code.
- Prefer invoker privileges and RLS. Use `SECURITY DEFINER` only when justified, with actor and resource authorization, a safe `search_path`, and narrow execute grants. Do not force it to work around a client query without reviewing the permission boundary.
- Verify columns and indexes before queries. Paginate growing lists. Use caching for heavy reads where it helps, invalidate after writes, and prevent older cache results from replacing newer realtime state. Keep auth scoped caches separate and clear them on logout.
- Treat production data as live. Test destructive and concurrency cases in staging or isolated fixtures; apply only reviewed new migrations, never replay old migrations on production.

## Mobile UI and localization

- Use `AppText` for displayed text outside the `AppText` implementation, except fixed brand artwork such as the PlaySpot splash wordmark and tagline when its original font must be preserved. Put static user facing copy in `AppStrings` and both Arabic and English translation files. Backend supplied names and user content remain data, not translation keys.
- Preserve the splash wordmark's explicit Orbitron typography across locales. Check the rendered text style when changing `LogoWidget` or replacing splash `Text` widgets; `AppText` applies locale typography and can override a `TextStyle` family.
- Keep RTL/LTR behavior correct with directional layout properties. Respect safe areas, keyboard insets, accessible touch targets, text scaling, and phone/tablet layouts where relevant.
- Use the existing theme colors and reusable controls when they fit. Extract repeated UI with the same behavior; avoid near duplicate styling and unnecessary wrappers. Keep the UI coherent with the current product design.
- Bind every form field. Handle loading, empty, error, retry, cancellation, and repeated taps visibly. Never show a success message for a failed mutation.
- Keep `BlocBuilder`/`BlocListener` rebuilds and effects scoped to the state they need. Do not fetch in `build()`. Dispose controllers, listeners, timers, and streams; ignore stale async responses. Repository/data source owns Supabase channels, and Cubit owns its stream subscriptions.
- Do not log tokens, PII, auth sessions, or secret values. Remove temporary debug code and commented out dead paths.

## Verification

- For bugs: reproduce → identify root cause → fix in the owning layer → add a meaningful regression test → verify. For new behavior, test the important business rule and authorization or concurrency where relevant.
- Use isolated fixtures or mocks for tests that could mutate live data. Network backed tests are allowed only when an isolated environment exists.
- Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-fatal-infos`, and relevant `flutter test` suites when available. Report what ran and what could not run. Wait for CI before claiming CI verification.
- After each scoped change, update the relevant handoff/evidence document with its current commit, verified checks, and remaining blockers. Keep this guide current when architecture or product direction changes; do not turn unverified plans into facts.

## REQUIRED FIRST READ — CROSS-STACK SYSTEM ATLAS

Before a feature, UI/UX, data-flow, pricing, session, offline, security, or integration change, read **[docs/PLAYSPOT_SYSTEM_ATLAS.md](docs/PLAYSPOT_SYSTEM_ATLAS.md)**, then verify current `dev`, overlapping PRs, and the owning source/tests. The atlas is a dated map, not evidence that a Draft PR is merged or a database function is deployed. This `AGENTS.md` remains authoritative for repository-specific engineering rules.

## Current cross-branch gates (24 October 2026)

Read [the financial contract verification](docs/audits/PLAYSPOT_FINANCIAL_CONTRACT_VERIFICATION_20261024.md) before approving Mobile financial PR #75: effective-schema replay remains blocked and the inspected deployed partial-payment status fails the expected contract. [Mobile Draft PR #81](https://github.com/salahaldensherief/playspot_V2/pull/81) contains a tested protocol simulator only; it does not control a PC or authorize a booking/payment. [Dashboard PR #80](https://github.com/salahaldensherief/Playspot_dashboard/pull/80) merged an independently tested Open Time completion response guard into `dev` at `03176100`; it does not validate final pricing or ledgers.
