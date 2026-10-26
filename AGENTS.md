# PlaySpot Mobile: agent engineering guide

This is the single source of agent guidance for the Flutter mobile repository. User instructions and verified product requirements take precedence. Apply these rules to code you touch; improve unrelated legacy code in focused follow-up changes.

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

## Verified financial contract update (25 October 2026)

The authorized schema-only snapshot was restored into a disposable PostgreSQL 17 container and matched 3,607/3,607 target catalog fingerprints before Draft migrations. The exact-schema fixture reproduced a canonical cash receipt deadlock under different operation IDs, a Dashboard discount committed before failed legacy collection, and missing discount metadata in `payments`. The Draft atomic cash checkout migration and isolated tests address these server paths; the Dashboard still calls the split legacy flow. Keep the migration Draft until Dashboard/Mobile compatibility, refunds, shift reconciliation and production recovery gates are verified. See [the exact-schema evidence](docs/audits/PLAYSPOT_ATOMIC_CASH_CHECKOUT_EXACT_SCHEMA_20261025.md).

The Draft checkout now accepts `p_amount_minor=NULL` to collect the authoritative remaining balance after discount, while explicit positive integer minor units remain available for partial collection. Its persisted receipt fingerprints the request and prevents replay with changed values. In the disposable exact-schema database, full settlement after an earlier partial receipt, lost-ACK replay, blind shift close and post-close rejection passed. No booking-cash refund/reversal RPC was found in the effective schema; do not claim refund accounting is verified. Dashboard integration remains a separate Draft change; deploy backend before any client invokes the new RPC, and do not deploy either without the owner's specific approval and recovery checks.

The old `complete_booking_payment` returns an idempotent response after a fully paid canonical receipt, but fails with `CASH_LEDGER_REQUIRES_CANONICAL_COLLECTION` after a partial canonical receipt. Exact-schema tests confirm no new ledger movement on that failure. Treat still-open legacy Dashboard clients as an explicit rollout/recovery blocker; do not describe backward compatibility as complete.

The owner's authoritative payment model uses manual InstaPay/wallet verification, optional cash, a small configurable reservation deposit or no-deposit cash booking, and final settlement after play. Never equate a submitted transfer proof with collection or session completion with a paid bill. An isolated synthetic future manual-transfer approval for 100.00 currently marks the full 100.00 paid and posts 100.00 to both payment and shift ledgers before play; the existing cash collector cannot then mix in cash. This is a release blocker requiring a coordinated deposit and mixed-method ledger design, not a safe one-line migration. See the exact-schema cash checkout evidence.

## Draft owner permission boundary (25 October 2026)

The effective schema let managers directly edit their own permission overrides, bypass role-template RPC checks with direct table DML, and self-promote through `lounge_staff`. A separate Draft migration revokes those writes, adds owner-controlled per-user overrides, a branch-scoped permission read and a protected audit trail, and limits manager delegation to permissions they hold. The isolated exact-schema authorization test passed 3/3 runs; the atomic checkout suite passed all 12 groups after this migration. Dashboard Draft PR #84 supplies per-employee controls; the full approval catalogue remains open. See [owner permission evidence](docs/audits/PLAYSPOT_OWNER_PERMISSION_BOUNDARY_20261025.md).

## Draft pre-session transfer guard (25 October 2026)

The effective backend quotes a future reservation deposit, but legacy `approve_manual_booking` calls full `complete_booking_payment` and records the entire expected price as collected before play. The separate Draft guard migration rejects that premature full manual-transfer entry, including direct legacy checkout, without altering existing rows. Exact-schema rollback-only synthetic tests pass, but old clients then cannot approve pre-session transfers. Keep this guard Draft and **never deploy it alone**. A verified-deposit ledger, mixed-method cash settlement, refunds/reversals, client updates and authenticated browser validation are still required. See [pre-session transfer evidence](docs/audits/PLAYSPOT_PRE_SESSION_TRANSFER_GUARD_20261025.md).

A rollback-only cancellation probe on the rebuilt 3,607/3,607 isolated schema found that `cancel_my_booking` changes a backend-paid future booking to `cancelled` while `payment_status=paid`, the completed payment and shift collection remain unchanged, and a cancellation/audit event is written. This is no proof of refund or forfeiture; never infer return of manual funds from booking status. The synthetic payment was not an externally verified bank transfer. Owner-configured refund policy, return confirmation and append-only reversal accounting remain release gates.

The owner has specified branch-level refund deadline and percentage configuration. Cancellation alone must not imply money was returned. An additional migration in this Draft blocks the legacy destination RPC from offering the entire expected price again after a recorded deposit; it is not a final settlement path and cannot be deployed without coordinated client and mixed-method ledger work.

## Draft canonical booking movement foundation (26 October 2026)

`private.booking_money_movements` is a Draft ledger for method-specific verified collections and actual refunds. The Draft has an authorized manual deposit attestation RPC and a movement-backed cash writer used by canonical atomic checkout. A payment guard prevents legacy `approve_manual_booking`/`complete_booking_payment` from treating a required deposit as full collection or overwriting movement-backed aggregates; old Dashboard tabs fail closed until updated. Isolated rollback-only fixtures proved EGP 20 verified electronic deposit plus EGP 130 cash settlement with two movements, two shift entries, EGP 150 gross and EGP 22.50 commission. The aggregate `payments` row remains unique by booking and uses `mixed` only as a compatibility marker. Payouts, actual refunds, clients and historical records still require integration. Do not merge or deploy this Draft alone, infer historical collection methods, or treat synthetic fixture success as full financial validation. Follow [the movement audit](docs/audits/PLAYSPOT_CANONICAL_BOOKING_MOVEMENTS_20261026.md) and coordinate with cash checkout, payout, refund and client Drafts.

The manual deposit RPC accepts only lounge-held funds from a lounge cashier. Platform-held transfers require a separately authorized platform-finance verifier and must not be confirmed from a customer screenshot or a cashier without account access.

Mobile booking badges recognize backend `partial` and legacy `partially_paid` as partially paid, and display `mixed` as transfer plus cash. These labels do not prove a completed refund, payout or real transfer.

## Draft branch refund policy (26 October 2026)

The product owner chose a refund deadline and percentage configured by each branch owner. The Draft backend stores immutable policy versions and snapshots the version on new bookings. Eligibility uses server timestamps and never implies that cash or transfer funds were returned. Historical bookings without a snapshot require manual review. Do not deploy the policy alone; actual refund obligations, verified manual return movements, client presentation and payout/shift reconciliation remain required. See [the branch refund policy audit](docs/audits/PLAYSPOT_BRANCH_REFUND_POLICY_20261026.md).

## Current dev transfer checkpoint (26 October 2026)

Backend/Mobile financial and owner-permission source from PRs #84–#88 was merged into `dev` by PR #89, but no hosted Supabase migration was applied by that source merge. Dashboard Preview isolation PR #85 was merged into its `dev`; Dashboard cashier and employee-permission PRs #83/#84 remain Draft. For the exact verified commits, local worktrees, APK, tests and outstanding Auth/financial blockers, read [the final Codex handoff](docs/ANTIGRAVITY_FINAL_CODEX_HANDOFF.md), then verify current remotes because this checkpoint can age.
