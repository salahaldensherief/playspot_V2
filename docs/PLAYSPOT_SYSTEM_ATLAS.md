# PlaySpot — Complete System Atlas & Agent Onboarding Handbook

> **START HERE BEFORE CHANGING ANY PLAYSPOT CODE.**
> Audience: an engineer or AI coding agent who has never seen PlaySpot before.
> Last source review: **24 October 2026**. This document describes inspected GitHub `dev` sources and explicitly labels incomplete or unverified work. It is a navigational map plus a business contract, **not a substitute for reading the current implementation**.
> Owner intent: preserve the existing product and make safe changes that work together across Mobile, Dashboard, and Supabase.

## 0. Evidence, precedence, and how to read this handbook

**Documented from code:** two Flutter clients, a shared Supabase backend, feature folders, routers, state management, migrations, tests, and the cited screens/contracts. **Proposed:** PanCafe Bridge and real Windows device control until verified. **Draft:** PRs not merged to `dev`. **Unverified:** anything that needs hosted schema checks, real hardware, browsers, payments, or staging tests.

Source snapshot at authoring:
- Mobile + canonical database migration repository: [salahaldensherief/playspot_V2](https://github.com/salahaldensherief/playspot_V2), `dev` commit `e50e686503161df4ea8dca2f4b7947484b0041aa`.
- Flutter Web operations dashboard: [salahaldensherief/Playspot_dashboard](https://github.com/salahaldensherief/Playspot_dashboard), `dev` commit `e111196f0ebaabe3a1ec39e4e2a2d094d388c621`.
- Mobile [Draft PR #75](https://github.com/salahaldensherief/playspot_V2/pull/75) contains financial Open Time work requiring exact-schema validation. Dashboard [PR #75](https://github.com/salahaldensherief/Playspot_dashboard/pull/75) was closed without merge after its visual redesign was rejected. Dashboard scheduler safety [PR #77](https://github.com/salahaldensherief/Playspot_dashboard/pull/77) was merged independently; its source is in this `dev` snapshot.
- Current branch/production state may change immediately after this document was written. Always fetch `origin/dev`, review `AGENTS.md` in BOTH repos and verify PR status before relying on the snapshot.

**Precedence** when sources disagree:
1. User's explicit current product requirement and authorized scope.
2. Actual current deployed schema/function contract **only if safely, independently verified** for the target environment; never write to production merely to inspect.
3. Current `dev` and the feature branch being edited, integration tests, source-of-truth owners, and `AGENTS.md`.
4. Recent verified contract documents.
5. Historical plans/review migration files and this handbook.
Never infer “deployed,” “paid,” “device controlled,” or “external booking confirmed” from a UI label, a historical document, or green mock tests.

## 1. Product: who uses it and why it exists

PlaySpot is an Egypt-first platform that connects customers with gaming lounges while also offering an operations suite to venue owners and staff. It supports **Gaming PC**, **PlayStation 4/5**, and mixed venues, with the **room/station/resource** abstraction connecting mobile discovery, booking capacity, session timing, price, and cashier operations.

**Customers** use the Flutter mobile app to discover/filter lounges, inspect lounges/rooms/pricing, reserve times, check out, view receipts/bookings, manage active sessions, request help/extension, order canteen products, redeem loyalty, receive notifications, use tournaments, and manage account/support.

**Venue owners/managers/cashiers** use a Flutter Web dashboard for room/station operations, session start/stop, cashier payments, shifts, inventory, product sales, prices, marketing, staff, customer requests, and reports. Capabilities differ by venue role and granular server permission. Venue ownership is **not** platform super-admin privilege.

**Platform super admins** handle multi-venue administration, onboarding/KYC review, users, platform payouts, policy and system settings, support, loyalty and tournaments. They require separately authorized server operations.

**Business evidence:** an earlier handoff summarized four lounge-owner responses and a newer directive reports seven. The underlying records, timing and overlap have not been reconciled. Treat those summaries as qualitative leads, **not a market-share estimate**. Staff mistakes, shift accounting and booking conflicts are reported pain points; some operators do not want new bookings or to switch systems. See the read-only [market and capability review](https://github.com/salahaldensherief/playspot_V2/pull/79) (Draft PR #79) for evidence boundaries.

Three intentionally separate venue operating modes:
1. **Booking-only:** the incumbent program stays; PlaySpot booking **requests** require human availability confirmation. Never pretend the request reserved PanCafe inventory.
2. **PlaySpot native:** server-authorized PlaySpot booking, session, POS, shifts and pricing, with physical terminal control **only where a verified agent/device path exists**.
3. **Bridge:** a vendor-neutral adapter; every declared ability must be verifiably supported. PanCafe is the initial candidate for investigation, not a dependency of core booking logic.

## 2. End-to-end architecture and ownership

```text
                        CUSTOMER PHONE
                 Flutter Mobile (playspot_V2)
   screens -> Cubit/state -> use case/repository -> remote datasource
                                      |
                                      v
                         SUPABASE SHARED BACKEND
                 Auth + Postgres/RLS + RPC + Storage
                    Realtime + selected Edge Functions
                                      ^
                                      |
                  Flutter Web Dashboard (Playspot_dashboard)
          routes/screens -> Cubits -> use cases/repositories -> I/O
                                      |
                    OPTIONAL FUTURE LOCAL/BRIDGE LAYER
                   offline cashier / authorized Windows agent
                  (NOT proof of live PanCafe integration)
```

**Only server-side authorization and data constraints protect business integrity.** UI buttons are presentation. The server must decide lounge membership and privileges, active account status, room capacity, booking holds, authoritative price, collection, paid/due, shift eligibility, stock mutation, refunds, and lifecycle transitions.

When debugging, always trace **Widget/route -> Cubit/state -> domain/use case -> repository contract -> datasource/RPC/table -> RLS/grants/function -> response parse -> Realtime/UI**. Some features omit a layer: trace what actually exists; do not create ceremonial abstractions.

**Data semantics to keep separate:**
- Station booking availability vs physical device connectivity.
- Booking status vs session active/closed vs payment status.
- Proposed quote vs reserved hold vs committed booking.
- Amount charged/due vs real amount collected vs payout/commission liability.
- Client-side clock estimate vs authoritative server timestamps.
- Local queued/offline command vs server-acknowledged mutation.
- PlaySpot human confirmation vs vendor inventory confirmation.
- Source code existing vs deployed production contract.

## 3. Repository A — Mobile + canonical backend (source map)

Path: [playspot_V2](https://github.com/salahaldensherief/playspot_V2).

- `lib/main.dart`: bootstrap; inspect initialization order before changing app startup.
- `lib/art_core/router/app_router.dart`, `router_keys.dart`: GoRouter routes, guards, route arguments, deep links and notification navigation. Protected routes include booking, checkout, bookings, favorites, notifications, active session, tournaments and private profile paths.
- `lib/art_core/`: shared visual components, theme, `app_strings.dart`, navigation, localization-adjacent helpers. Treat existing user design as product intent.
- `lib/core/di.dart` + `lib/core/di/modules/`: GetIt composition; a new repository must be registered with the matching lifetime.
- `lib/core/`: auth-adjacent cache/security, services, network/error types, realtime watcher mixin, notifications, and DI.
- `lib/features/<feature>/{presentation,domain,data}/`: feature boundaries; not every feature uses every subdirectory.
- `assets/lang/ar.json` and `en.json`: Arabic/English; use `AppStrings` and existing text components; preserve RTL/LTR.
- `supabase/migrations/`: main canonical migration chain. `supabase/review/migrations/` and `supabase/repairs/` may be review-only, historical or not deployed. **Never replay the entire folder blindly.**
- `supabase/tests/`: SQL/JS/native PostgreSQL fixtures and contract suites; inspect runtime/ports before running.
- `test/`: widget, unit, model, Cubit, datasource, router, service and regression tests.
- `android/`, `ios/`, `web/`: platform builds and integration constraints. Android release signing requires correctly configured credentials, not a debug substitute.

### Mobile UI/UX map — real screen entry points

| Customer journey | Entry screen / controls | Main state/data owner; what to inspect |
| --- | --- | --- |
| First launch / maintenance | `features/splash/presentation/splash_screen.dart`; `onboarding/presentation/onboarding_screen.dart`; `app_status/` | Router redirects + app status/force-update; user session guard |
| Sign-in/up, OTP, profile setup | `features/auth/presentation/sign_in/signin_screen.dart`; `sign_up/`; `forgot_password/` | `auth_repository`, Supabase Auth and local secure state; callback/referral isolation |
| Browse lounges | `features/home/presentation/home_screen.dart`; `features/main/presentation/main_screen.dart` | Home Cubit -> lounge discovery repo/datasource, loading/empty/caches |
| Search/filter | `features/search/presentation/search_screen.dart` | Search Cubit / remote queries; geolocation only with permission |
| Lounge & room details | `features/lounge_details/presentation/lounge_details/lounge_details_screen.dart` and `room_details_screen.dart` | Room capacities, features, availability, hourly rates, reviews; server quote/eligibility later |
| Select date/time/duration | `features/booking/presentation/booking_screen.dart`, `booking_cubit.dart`, `widgets/duration_selector.dart` | Room slot availability, waitlist, date/time, pricing quote, hold |
| Review & checkout | `features/checkout/presentation/checkout_screen.dart`, `checkout_cubit.dart` | Hold identity, server checkout, vouchers/points, payment proof, idempotency/retry; **not** client-owned price |
| My bookings / QR / rebook | `features/my_bookings/presentation/my_bookings_screen.dart` | Bookings Cubit, timeline, QR, cancellation rules, quick rebook, server status |
| Active session / time/requests | `features/active_session/presentation/active_session_screen.dart` | ActiveSession Cubit/model, realtime watcher, canteen, extension, staff call, review, final server close |
| Notifications | `features/notifications/presentation/notifications_screen.dart` | FCM/local notifications, notification strategy/router; no private action for logged-out user |
| Rewards & account | `features/profile/presentation/profile/profile_screen.dart`, `redeem_points_screen.dart`, `my_vouchers_screen.dart` | Loyalty balances/events are server-owned; privacy/logout/deletion |
| Support/legal | `features/profile/presentation/support/help_support_screen.dart`, `legal/` | Tickets/FAQ, policies and privacy |
| Tournaments | `features/tournaments/presentation/tournaments_feed/tournaments_feed_screen.dart` and details/match/history screens | Registrations, brackets/results, payment/status/points and realtime roles |

**UI conventions from Mobile `AGENTS.md`:** shared `AppText` rather than arbitrary raw text, `AppStrings` + both locales, consistent art_core theme/colors, responsive safe-area/keyboard/text scaling, loading/empty/error/retry/repeated-tap states, thoughtful `buildWhen`/`listenWhen`, disposal of streams/controllers. Do not put I/O in `build()`. A checkout success toast must follow a confirmed authoritative response.

## 4. Repository B — Flutter Web Operations Dashboard (source map)

Path: [Playspot_dashboard](https://github.com/salahaldensherief/Playspot_dashboard).

- `lib/main.dart`: initialization and app boot.
- `lib/core/router/app_router.dart`, `router_keys.dart`, `lounge_admin_routes.dart`, `super_admin_routes.dart` and `router_guards.dart`: role-aware navigation, auth redirects and protected route ownership.
- `lib/art_core/`: shared theme, components, layouts, translations and `AppStrings`.
- `lib/core/di/`: GetIt registration and shared dependencies.
- `lib/features/`: role-dependent operations modules.
- `assets/translations/`: AR/EN text, RTL/LTR.
- `assets/audio/` and `lib/core/audio/`: cashier notification tones; browser autoplay/permission constraints apply.
- `lib/features/offline_cashier/`: encrypted local projection, permit-based commands, journal, replay and conflict review. Not a generic “save every write offline” facility.
- `lib/core/services/hardware_bridge_service.dart`: existing hardware-related service; **not proof of a functioning production Windows agent**.
- `supabase/functions/`: selected Deno/TS/JS Edge Functions for privileged server workflows, e.g. announcements, FCM, owner/staff provisioning, deletion/recovery; these are not deployed merely by merging Dart/TS source.
- `supabase/migrations/` and numbered `supabase/*.sql` contain dashboard-side history/contract references. Coordinate canonical backend migrations with Repo A.
- `test/features/`, `test/fixtures/`, `test/harness/`: widget/unit/contracts, offline fixture harness.
- `vercel.json`, `web/`: Flutter Web SPA deploy specifics. **Pushing branches can auto-trigger Vercel previews.** Preview != production.

### Dashboard UI/UX — who sees what

| Area | Primary path | Key workflows |
| --- | --- | --- |
| Operator shell / overview | `features/analytics/presentation/dashboard_screen.dart`, `widgets/lounge_owner_dashboard_view.dart` | Lounge-scoped stats, sessions, requests, room streams, shift/action panels |
| Live Operations | `features/bookings/presentation/pages/bookings_page.dart`, `widgets/live_sessions_operations_board.dart`, `cashier_sessions_workspace.dart` | Start/close, bookings, live session details, cashier controls and manual bookings |
| Station controls | `features/bookings/presentation/widgets/room_occupancy_card.dart`; `station_control_drawer.dart` | Occupancy vs session/availability, active booking, actions, timing and billing |
| Open Time | `features/bookings/presentation/widgets/open_time_session_dialog.dart`; `features/lounges/presentation/widgets/lounge_open_time_policy_section.dart` | Per-room policy, cashier initiation, elapsed time vs fixed countdown, canonical close |
| Bookings history | `features/bookings/presentation/pages/booking_history_page.dart` | History/status, audit and reporting |
| Rooms/resources | `features/rooms/presentation/pages/room_management_page.dart` | Room types, rates, capacity, maintenance and availability |
| Pricing | `features/pricing/presentation/pricing_screen.dart` | Scoped pricing rules/overlap/quote; server is authoritative |
| Lounge profile/branches | `features/lounges/presentation/pages/lounge_profile_page.dart`; `lounges_page.dart` | Owner details, policies, operating hours, settings; super admin wider scope |
| Onboarding/KYC | `features/onboarding/presentation/pages/lounge_setup_page.dart`; `features/kyc/` | Owner setup, submission/review, identity docs/permissions, staged activation |
| Cashier shift | `features/shifts/presentation/shift_management/` and `shift_history/shift_history_screen.dart` | Open/close, expenses, payments, reconciliation, permission checks |
| Offline cashier | `features/offline_cashier/presentation/offline_workspace_page.dart` | Explicit permitted local writes, sync, conflict review; limited feature set |
| Canteen/extras | `features/canteen/`; `features/lounges/presentation/pages/extras_management_page.dart` | Stock/orders, combo rules, prices, low-stock and upsell |
| Staff/permissions | `features/staff/presentation/staff_management/staff_screen.dart`; `features/permissions/` | Role assignment and permission-specific actions |
| Finance/payouts | `features/payouts/presentation/pages/lounge_admin_payouts_page.dart`; `super_admin_payouts_page.dart` | Reconciliation/settlement/collection; never equate due with collected |
| Requests/reviews | `features/requests/`, `features/reviews/reviews_screen.dart` | Assistance, customer requests, review responses |
| Marketing/loyalty | `features/marketing/`, `features/loyalty/` | Offers, campaigns, points, growth |
| Tournaments | `features/tournaments/presentation/tournaments_screen.dart` | Event configuration, brackets, roster and match workflow |
| Platform administration | `features/users/`, `categories/`, `support/`, `system/`, `audit/` | User & lounge governance, catalog, policy/support, system settings, audit |

The Dashboard router explicitly separates **super-admin routes** from **lounge-admin routes**. It scopes shared Cubits to the shell and watches the selected venue where appropriate. Always inspect actual role/permission logic and server privileges; hiding a tab is not authorization.

### Live Operations operator mental model

The approved Dashboard `dev` presentation is the visual baseline. The cashier still needs clear PC, PlayStation and other resource groups, current availability, next booking, session mode, elapsed or remaining time, requests, due/collected distinction and fast authorized actions. Improve those workflows within the accepted design; do not revive the rejected PR #75 layout. Reuse shared components where the same interaction repeats, and support Arabic as a first-class locale.

A station's **room availability**, **booking/session state**, **payment**, **device heartbeat/connectivity**, **external vendor confirmation**, and **synchronization health** are independent concepts. Do not collapse them into a misleading green/red field. “Available in PlaySpot” does not prove free in PanCafe.

At this `dev` snapshot, the dashboard has session cards, booking controls and clocks. The independent scheduler safety fix from Dashboard PR #77 alerts cashiers about expired sessions instead of completing them through a generic status transition. Verify that authorized cashiers can still reach canonical close and that reconnect/restart does not strand sessions. The station-grid redesign in closed Dashboard PR #75 is historical review material, not an approved implementation.

## 5. Domain dictionary (sensitive meaning)

| Concept | Meaning / invariants | Source location to verify |
| --- | --- | --- |
| Lounge / venue | Tenant and ownership boundary. Location, timezone, policy, onboarding and staff access are scoped to its ID | `lounges` models, lounge RPCs and permission helpers |
| Branch | Operational scope; switching must invalidate old room/booking streams and caches | Dashboard login/shell, Cubits and branch queries |
| Room / station / resource | Booking inventory and play-mode/rate unit; not a PC heartbeat | `rooms` schema, room repo, booking exclusions |
| Booking | Desired or committed slot, lifecycle statuses, holds and conflicts | `bookings` schema; Mobile Booking/Checkout, Dashboard BookingCubit |
| Hold | Temporary capacity claim, must expire/release and be revalidated before checkout | backend hold/checkout migrations |
| Open Time | Running without predetermined fixed duration; final price from agreed policy and elapsed time | open-time fields, start/complete RPC, pricing snapshot |
| Fixed session | Scheduled duration, server timestamps and extension transitions | start/extend/close RPCs |
| Payment | Money event/method/state; not identical to charge amount | `payments`, booking payment status, shift payment/ledger |
| Amount due | Outstanding obligation, not a cash receipt | finalization/collection RPC results |
| Shift | Individual cashier's authorized cash working context; open/close/reconciliation | `shifts` and `shift_payments`, dashboard Shifts, offline permit |
| Canteen order | Itemized goods/stock/prices/status; order placement is not necessarily collection | `canteen_orders`, `canteen_order_items`, stock/contracts |
| Pricing rule | Effective rate determined by scoped time/date/room/mode priorities | `pricing_rules`, quote RPC and tests |
| Permission | Server-checked actor/action/tenant capability, separate from menu visibility | RLS, grants, `has_lounge_permission`, `app_permissions` |
| Audit | Durable attributed action/transition provenance, not a console log | audit tables/events, dashboard audit |
| Offline writer | A specific authorized cashier/device/shift with exclusive scoped writer generation/lease | coordinated offline backend + encrypted journal |
| Vendor bridge | Verified external capability with explicit status/provenance | Bridge docs/PRs; **no verified PanCafe API** |

**Exact enum labels, table columns, RPC signatures and grants MUST be re-read from current migrations and effective deployed schema.** Historical docs may contain names later renamed or overridden.

## 6. Primary cross-stack data flows

### 6.1 Auth, onboarding and permissions
1. Mobile customer signs in/signs up through the auth feature; Supabase Auth owns identity. Social OAuth callback handling is distinct from marketing referrals (Mobile PR #74 on `dev`).
2. Dashboard login resolves user account/role/venue, loads permission state and passes router guards. Logout clears scoped local data/subscriptions.
3. Owner onboarding saves venue/contact/geolocation/rooms/products/payment preferences/evidence, submits for review; super-admin KYC decision is server-checked. **A saved draft or UI “completed” state is not automatically a published, publicly bookable lounge.**
4. Staff provisioning/disable operations use authorized RPC/Edge boundaries; do not write Auth user rows directly.
5. Every sensitive mutation revalidates account active/not-banned, tenant, resource ownership, required permission, and grant. See `docs/BOOKING_ACTOR_AUTHORIZATION.md`, `docs/CANONICAL_LOUNGE_AUTHORIZATION.md` and Dashboard `docs/ONBOARDING_REVIEW_FLOW.md`.

### 6.2 Discovery → room → slot → hold → checkout
1. Home/Search loads available lounges and cards via its repository; room details display station/device type, facilities, normal prices and review information.
2. Mobile `BookingCubit` requests room bookings/slot prices; `quote_booking_price` creates a **preview** with pricing segments. Chosen date/time/play mode/extra controllers change the quote.
3. Select date/time, obtain a **server-issued capacity hold**; a stale response to an old selection must be ignored, and an abandoned hold released. Do not treat a disabled UI slot as an exclusive DB lock.
4. Checkout sends immutable requested details with authorized actor and hold/operation identity. The server rechecks capacity, price, voucher/loyalty permissions and mutations, then commits or rejects.
5. Different payment methods (cash/manual transfer/online) have separate evidence and state. A payment-intent or manual upload alone is not “collected.”
6. Success requires matching server booking/receipt identity. Update My Bookings/realtime and dispose stale pending operations.
7. **Failure cases:** duplicated taps, stale quote, expired hold, two cashiers, network drop before request, lost ACK after commit, restart, replay, manual transfer proof. Draft Mobile PRs #71/#72/#73 require combined/exact-schema verification; do not force-merge on green widget CI alone.
8. Quick Rebook **re-enters quote/availability/hold**; it must not copy stale original price or guarantee slot availability.

### 6.3 Cashier booking/session lifecycle
1. Dashboard booking/live-operations projection watches selected lounge, rooms, bookings, requests and the active session feed. Refresh/scope changes must not revive previous lounge state.
2. Staff may manually add a booking/walk-in only if current role, active shift, and server capacity/payment policy permit.
3. Fixed booking session starts using the authorized start RPC after temporal readiness and payment checks. UI may show a start button but cannot bypass server transition guards.
4. Active fixed session shows planned end, remaining time and allowed extension/canteen actions. Server approval of an extension **is not collection**.
5. An expired clock is an **operator alert**, not authorization to call a generic status-update-to-completed RPC. Dashboard PR #77 merged this scheduler safety change; test that the canonical close remains reachable.
6. End/close through **canonical session-close RPC**, not just UI status mutation; confirm the response identity, update booking/room/shift/cash views.
7. Closing play may finalize a liability; it must not automatically insert a collection receipt.
8. Room may be freed only when capacity/occupancy invariants permit. A stale room card or duplicate active booking requires conflict handling.

### 6.4 Open Time special workflow
- Per-room policy fields observed: `open_time_enabled`, `open_time_pricing_mode`, `open_time_custom_hourly_rate`, `open_time_price_multiplier`, `open_time_minimum_minutes`, `open_time_rounding_minutes`, `open_time_max_minutes`, `open_time_buffer_before_booking_minutes`.
- Modes observed in migrations: `same_hourly`, `custom_hourly`, `hourly_plus_percentage`. **No fixed global surcharge.**
- Authenticated cashier/server creates via `start_open_time_session`. Do not expose public customer creation unless a separately verified business decision and permission contract allows it.
- Server should snapshot applicable rate and policy in `open_time_pricing_snapshot`. Pricing changes after start must not silently reprice an existing session.
- Mobile shows **elapsed**, not a fake remaining countdown; it hides fixed-session expiry/extension prompts. Dashboard shows the same distinction and the policy.
- The final time charge remains **non-final** during play unless a real authoritative running quote contract exists. Display genuine recorded canteen obligations separately from unfinalized time; do not mislabel a charge as paid.
- Canonical close path inspected in Draft #75 is `complete_booking_session`; an old source migration defined `complete_open_time_session` using mutable room fields and a potentially false paid state, but previous read-only hosted inspection did **not** find that older function deployed. Never present the historical bug as current production fact without confirming the live catalog.
- **Draft Mobile PR #75 implements the reviewed presentation fixes**: running Open Time shows committed canteen charges apart from unfinalized time and actual collection; completed duration prefers authoritative Open Time end timestamps. Its focused, restart and reconnect tests passed on the reviewed PR head. These changes are **not on `dev`** and do not satisfy the effective-schema, RLS and ledger gate. Re-read current PR head and review comments before integration.
- Test: policy variants, minimum, rounding, max, future booking buffer, concurrent starts, duplicate/lost-ACK closes, paid/due and ledger, DST/midnight, restart/reconnect and old clients.

### 6.5 Cash collection, refunds, payouts and shifts
1. Quote/charge computes an obligation; payment collection is another authorized and auditable event.
2. State distinctions: unpaid, partial, paid, refunded (status names must match current schema).
3. Example: total 230 EGP, 180 collected → 50 due. Never invent a 50 EGP payment because the session closed or was extended.
4. Partial payments, refunds and discounts must update the correct ledger/booking/shift projections exactly once, with scoped actor and idempotency.
5. Shift open, cash collection, expenses, close/handover and blind cash-read permissions must reconcile with actual receipts and actor/venue identity.
6. Platform commission and payouts have distinct liabilities/provenance; do not derive settlement solely from a UI total. Source: `features/payouts/`, `features/shifts/`, `docs/backend/PARTIAL_CASH_COLLECTION.md`, `docs/backend/FINANCIAL_CLIENT_PRIVILEGES.md` and latest migrations.
7. The Dashboard refunded/partial labels received targeted previous dev fixes; do not regress them.

### 6.6 Canteen, inventory, combos and upsell
- Dashboard maintains product/extras, stock tracking, combos, upsell and alerts; Mobile active session displays menu and places session-linked orders.
- Order requests validate quantities, price snapshots, stock availability and tenant authorization on the server.
- Distinguish order accepted, product served/cancelled, charge accrued and cash collected.
- Offline cached stock and receipt updates are not enough to prove hosted stock reconciliation. Review `docs/backend/OFFLINE_CANTEEN_RECONCILIATION.md` and Dashboard `docs/OFFLINE_CASHIER_CONTRACT.md` before mutation.

### 6.7 Active session realtime, assistance and notifications
- Supabase Realtime/postgres changes and refresh flows feed client UI. Mobile `active_session_remote_data_source.dart` tries `get_active_session_details` then fallback select; it hydrates booking, lounge/room, order records. Subscription is scoped by booking ID.
- Mobile `ActiveSessionCubit` manages stale async request versions/subscriptions and notification/lifecycle cleanup, and rehydrates after updates.
- Local expiry notifications and live activity countdown belong to **fixed-duration** sessions; Open Time must not get a fictitious end warning.
- Dashboard watches bookings/rooms/requests; server state is authoritative. De-duplicate audible tones and respect browser autoplay and operator preference; a notification sound does not prove a server mutation.
- Assistance requests/extension requests require backend actor/booking validation.

### 6.8 Tournaments, loyalty, reviews, support
- Mobile tournaments list/details/register/check-in/participant/match/history UI; dashboard manages tournament event/roster/bracket/permissions. Server determines registration/payment/reward issuance; tournament capacity can interact with room availability.
- Loyalty points, voucher redemption and tier balances must be updated through guarded server operations. Do not trust displayed wallet amounts or duplicate tournament awards.
- Reviews and support are scoped to valid user/venue/booking. Profile/account deletion requires coordinated auth/database/storage behavior.
- Find exact handlers in `features/tournaments`, `features/profile`, Dashboard `features/loyalty`, `features/reviews`, `features/support` and server functions.

### 6.9 Offline and local cashier
- Dashboard contains an **encrypted local record**, secure key vault, scoped authority/bootstrap, command codec, outbox and receipt validation. A disconnected cashier does not automatically acquire the right to mutate any booking.
- Typical safe sequence: server grants writer permit/coverage/shift -> client persists command + projection atomically -> reconnect -> sequential idempotent replay -> validate server receipt IDs, amounts and scope -> persist acknowledgement -> clear only matching queued command -> manual conflict review if necessary.
- One writer per governed scope/generation. Another cashier and held bookings can conflict while offline; never ignore this.
- Review `lib/features/offline_cashier/`, `docs/backend/OFFLINE_CASHIER_BOOTSTRAP_CONTRACT.md`, `docs/backend/CASHIER_WRITER_PERMITS.md`, Dashboard `docs/OFFLINE_CASHIER_CONTRACT.md`.
- Browser storage/Hive/Web key security, hosted exact-schema reconciliation and real long disconnects require separate validation. Do not call a mock “production offline certified.”

## 7. Database, schema and integration guardrails

Backend technology: Supabase Auth + Postgres, RLS, SQL functions/RPCs, Storage policies, Realtime, selected Edge Functions. An Edge file in Dashboard Git is **not** evidence of a deployed function.

Where to start:
- `supabase/migrations/` in Mobile: source migration inventory and effective chronological overrides.
- `supabase/review/migrations/` and `repairs/`: do not apply as an automatic second chain.
- `supabase/tests/`: native PostgreSQL/Postgres-emulating fixture harness; check actual test script/migration dependencies.
- Dashboard `supabase/functions/`: server-side handlers and tests; check installed/hosted version separately.
- Key tables to discover (not exhaustive): `lounges`, `rooms`, `bookings`, `payments`, `pricing_rules`, `shifts`, `shift_payments`, `canteen_orders`, `canteen_order_items`, staff/permission/points/tournament/notifications/reviews/support entities, offline writer/permit/receipt tables.
- Key RPC families to search rather than guessing signature: booking hold and checkout; `quote_booking_price`; `get_room_slots_with_prices`; `start_open_time_session`; `complete_booking_session`; session start/extension/collection; staff/shift; RLS/permission helpers; waitlist; account/loyalty/tournament lifecycle.
- **Time:** store instants with timezone semantics; lounge local time and `business_date` follow lounge configuration (often Africa/Cairo) and overnight operating boundaries. Date + clock strings need intentional interpretation. Test DST and midnight.
- **Security:** RLS is not enough without grants; `SECURITY DEFINER` requires explicit account, actor and venue checks plus safe search_path/narrow execute privileges. Do not expose service-role keys to clients. Tests must include unauthorized cross-tenant cases.
- **Financial testing:** assert rows, ledger, amount_paid, amount_due, replay IDs, and shift totals, not just a success boolean. Distinguish native PG exact-schema tests from PGlite/mock/fixture-only tests.
- **Deployment:** production migration ledger and source migration files have drifted historically. Read-only catalog inspection + isolated schema reconstruction + reviewed forward migration are required. Never reset/replay live DB.

## 8. UI/UX rules for BOTH apps

**Mobile design:** existing branded visual system, reusable widgets, cards, responsive ScreenUtil and localized AppText, clear session clock, quote detail, status/error/empty states, safe tap/keyboard behavior, consistent accessibility. Existing design is intentional; no generic Material UI overhaul.

**Dashboard design:** preserve the accepted `dev` presentation. Improve the existing rooms/cards and cashier drawer through focused, reviewable changes; group PCs, PlayStation rooms and other resources clearly. Distinguish fixed countdown from open elapsed and due from collected. Keep role-aware actions, text alongside status colors, actionable alerts, RTL Arabic/English and 1366px laptop performance at 6/20/40 mixed stations. Research other dashboards for usable patterns without copying proprietary assets or replacing the UI wholesale.

For every UI change test: loading, empty, error, permission denied, stale/no network, repeated action, narrow width, large text, AR/EN, different access roles, and mutation-response state. If an operator action has not been implemented server-side, show unavailable/unsupported rather than a fake success.

**Source of UI truth:** art_core tokens and existing widgets; AR/EN translation files; route keys, existing Cubits, design patterns in the feature. Do not invent a new style system in a feature fix.

## 9. Integration status, known drafts and risk register — snapshot

| Work | Observed GitHub status at atlas authoring | Agent action |
| --- | --- | --- |
| Mobile `dev` | Base commit listed above | Fetch current HEAD before modifying |
| Dashboard `dev` | Base commit listed above | Fetch current HEAD before modifying |
| Mobile PR [#75](https://github.com/salahaldensherief/playspot_V2/pull/75) | **Open Draft** at reviewed head `b9edcf97`; canteen/duration corrections and tests exist outside `dev` | Recheck current head and review comments; exact effective-schema financial, RLS and ledger validation remains |
| Dashboard PR [#75](https://github.com/salahaldensherief/Playspot_dashboard/pull/75) | **Closed without merge**; proposed visual redesign rejected | Preserve `dev` UI; only use the branch as historical evidence |
| Dashboard PR [#77](https://github.com/salahaldensherief/Playspot_dashboard/pull/77) | **Merged** as `86f731fd` | Independently merged scheduler safety; verify canonical close and reconnect operationally |
| Dashboard PR [#78](https://github.com/salahaldensherief/Playspot_dashboard/pull/78) | **Merged** as `e111196f` | Current UI direction is documented on `dev` |
| Mobile PR [#77](https://github.com/salahaldensherief/playspot_V2/pull/77) / [#78](https://github.com/salahaldensherief/playspot_V2/pull/78) | **Merged** as `f8218550` / `e50e6865` | Original splash Orbitron typography and final evidence report are on `dev` |
| Mobile PR [#79](https://github.com/salahaldensherief/playspot_V2/pull/79) | **Open Draft** research baseline at last review | Read the capability matrix; source inspection is not end-to-end validation |
| Mobile [#71](https://github.com/salahaldensherief/playspot_V2/pull/71), [#72](https://github.com/salahaldensherief/playspot_V2/pull/72), [#73](https://github.com/salahaldensherief/playspot_V2/pull/73) | Finance/checkout draft/integration candidate during last review | **Do not merge without never-committed checkout recovery and exact-schema financial testing** |
| Bridge [#68/#69](https://github.com/salahaldensherief/Playspot_dashboard/pull/69) | Prior mock/review work, draft | Read actual state; no verified PanCafe API or Windows production agent |
| Previous Mobile PR #74 | Merged into dev | OAuth callback/referral code isolation |
| Previous Dashboard PRs #71, #72, #74 | Merged into dev | Announcement auth source guard; partial payments; refunded labels; production Edge rollout separate |
| PS-001 through PS-009 and other reviews | Mixed source, hosted and test evidence; not universally closed | Reconcile audit items individually; avoid blanket “all resolved” |

**Explicit unresolved/verification gates:** Open Time canonical close/ledger/RLS on disposable *effective* schema; two-cashier concurrency; payment vs collection; replay after unknown outcome; lost-ACK and never-committed checkout; external inventory; offline endurance; real mobile reconnect; browser 6/20/40 device UX and audio; platform announcement production version; signed Android AAB/16 KB and Play policy; Vercel staging/production safeguards. Green Flutter CI **does not** close them.

Documents to read with PR #75:
[01–16 report folder](https://github.com/salahaldensherief/playspot_V2/tree/feature/open-time-customer-display/docs/audits/playspot-pancafe-open-time-readiness).

## 10. Safe engineering workflow — mandatory for every new agent

**A. Establish ground truth before edits**
1. Confirm access to BOTH repositories and their correct remote `origin`.
2. `git status --short`, `git worktree list`, `git fetch origin --prune`, `git log -5 --oneline origin/dev`. Do not overwrite unknown local changes.
3. Read each repo's `AGENTS.md` and this handbook. Read the affected feature's contracts and tests.
4. List open PRs against `dev`; inspect overlapping/draft changes. A file on an open PR is **not** on `dev`.
5. Identify environment and secrets without printing them; read `.env.example`.
6. State the feature owner, business invariant, expected response and evidence level.

**B. Reproduce, trace, fix and verify**
1. Reproduce defect via current source, failing test or safe isolated fixture.
2. Trace UI -> Cubit -> repository -> datasource -> RPC/RLS -> result.
3. Identify whether the owner is Mobile, Dashboard, backend, vendor, or release configuration.
4. Make smallest justified modification, preserve compatibility and analytics/permissions/finance.
5. Add unit/widget/integration/RLS/concurrency tests proportionate to risk.
6. Format only relevant Dart files; run analyzer/tests and review CI.
7. If an exact-schema fixture is impossible, mark financial changes Draft/Blocked and do NOT invent evidence.

**C. Git delivery**
1. Create focused feature branch from verified current `dev` (or PR head if explicitly continuing a draft); respect unrelated working trees.
2. Review all changed files, `git diff --check`, generated files and secret exposure.
3. Push feature branch; open PR with **base `dev`**, tests and blockers.
4. Merge only independently safe, fully tested changes after final-head CI, branch update and diff review. Record exact merge SHA and verify new remote `dev`.
5. Never force-push, touch `main`, deploy Supabase, trigger real payments, broadcast real notifications or power physical devices without distinct authorization.
6. Note dashboard Git pushes can trigger Vercel **preview** automatically: check configuration; preview ≠ production.
7. Record continuing work in a PR report/checkpoint so another agent can resume.

**Quick baseline commands (run separately in each clone):**

```bash
git status --short
git remote -v
git worktree list
git fetch origin --prune
git log -5 --oneline origin/dev
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test
```

Backend: use repository-specific scripts under `supabase/tests` with documented native PostgreSQL environment. Dashboard production-style compile check: `flutter build web --release` with safe build-time public variables. Do **not** treat signed Android AAB as available unless actually built with authorized release signing and verified; CI/debug-signed APK is not Play Console certification.

**Quality gates by type**
- UI-only: widget tests, AR/EN RTL, responsive/browser for desktop, access/error/retry, CI.
- Booking/session change: simultaneous actions, RLS, capacity/hold, timestamps, actual close, realtime/cross-client consistency.
- Financial change: isolated effective schema and ledger assertions; idempotency, partial/paid/due, shift attribution, refund, old-client.
- Offline/vendor/hardware: device/permit scope, disconnect/reconnect, provenance and receipt validation; physical controls require hardware safety and explicit approval.
- Release: valid stage build, secrets, policy, smoke, rollback; separate production authorization.

## 11. When you receive a feature request: find the owner quickly

| Request | First inspect in Mobile | First inspect in Dashboard | Backend contract |
| --- | --- | --- | --- |
| Add/edit a booking | `features/booking`, `features/checkout` | `features/bookings` | holds/checkout/status/availability |
| Price, discount, voucher | booking quote, checkout models, loyalty | `features/pricing`, booking financial widgets | pricing engine, snapshots, collection, vouchers |
| Change Open Time | active session UI/data model | open-time dialog, live sessions, policy widget | start/complete and open-time snapshot |
| Start/end a session | My Bookings + ActiveSession | cashier drawer/scheduler, session operations | server session start/close, shift and RLS |
| Show device statuses | details/booking availability | RoomCubit, Live Operations, bridge | source-specific availability; no fake heartbeats |
| Canteen | `features/active_session` | `features/canteen`, extras | stock/order/totals/receipt |
| Cashier shift | booking/session state | `features/shifts`, offline workspace | writer leases, shift ledger/permissions |
| Login/roles | `features/auth`, router | `features/auth`, router/permissions | Auth, user eligibility, RLS/grants |
| Loyalty & vouchers | profile/checkout | `features/loyalty` | points/vouchers atomicity |
| Tournaments | `features/tournaments` | `features/tournaments` | roster/match/payment/awards |
| Notification sound | `core/notifications` | `core/audio` | only authorized notification events |
| Offline / hardware | active session expectations | `features/offline_cashier`, bridge service | writer protocol, receipts, vendor adapter |
| Account deletion | profile/auth | users/support and server functions | Auth/storage/database cleanup |
| Deployment | Android/iOS configs | `vercel.json`, `web` | migrations/Edge deploy separate |

Note: "room C ubit" in this table means `RoomCubit`; use `features/rooms/presentation/cubit/room_cubit.dart`. Search actual symbols in source before editing.

## 12. How to maintain this handbook

This is an **index with behavioral invariants**, not an auto-updating schema registry. Update it when a feature route changes, a server-authority rule changes, a module is retired/added, or a Draft/production status is verified. Include precise file/PR/commit evidence. Cross-link rather than copying entire SQL sources; duplicated contracts drift.

Do not silently claim exhaustive source line-by-line coverage. This baseline was built from inspected routers, module trees, AGENTS/README/contracts and current PR evidence. Every new agent MUST inspect exact current files before implementation.

### Fast “new engineer” read order

1. This handbook plus both root `AGENTS.md`.
2. Both root `README.md` and target branch state.
3. Routing + main bootstrap + GetIt composition.
4. Business domain `booking -> checkout -> active session -> cashier close -> payment/shift`.
5. Canonical migrations, tested security/RLS/price contracts.
6. Related feature's Cubits/repositories/data sources and tests.
7. Open/draft PRs, then specific UI/UX change.
8. Validate with isolated tests; integrate only safe work.

### Short owner-facing summary (Egyptian Arabic)

**PlaySpot** مش تطبيق حجز بس: ده تطبيق عميل + Dashboard صالات + Backend واحد مسؤول عن الأسعار والحجوزات والفلوس والصلاحيات. الموبايل بيعرض ويحجز ويتابع الجلسات، والداشبورد بيشغّل الصالة والكاشير والشيفتات. **وجود زر أو حساب على الشاشة مش دليل إن السيرفر نفّذ العملية أو إن الفلوس اتحصلت.** كمان الـ Bridge بتاع PanCafe لسه محتاج API وتصريح وتحقق، وOpen Time لازم يفرق بين الزمن المنقضي والسعر النهائي المدفوع. أي Agent لازم يقرأ الفرعين، يتتبع الطلب للنهاية، ويختبر التغيير قبل دمجه في `dev`.

---

## Appendix — Mobile/backend checked source feature index

This index was generated from the inspected source tree at the baseline commit; it is a **discovery index**, not a statement every module is wired and enabled.

| Feature directory | Representative entry points (current dev) |
| --- | --- |
| active_session | `lib/features/active_session/data/datasources/remote/active_session_remote_data_source.dart` · `lib/features/active_session/data/repositories/active_session_repository_impl.dart` · `lib/features/active_session/presentation/active_session_cubit.dart` · `lib/features/active_session/presentation/active_session_screen.dart` |
| app_status | `lib/features/app_status/data/datasources/remote/app_status_remote_data_source.dart` · `lib/features/app_status/data/repositories/app_status_repository_impl.dart` · `lib/features/app_status/presentation/cubit/app_status_cubit.dart` · `lib/features/app_status/presentation/screens/force_update_screen.dart` · `lib/features/app_status/presentation/screens/maintenance_screen.dart` |
| auth | `lib/features/auth/data/datasources/remote/auth_remote_data_source.dart` · `lib/features/auth/data/repositories/auth_repository_impl.dart` · `lib/features/auth/presentation/banned_account_screen.dart` · `lib/features/auth/presentation/forgot_password/forgot_password_cubit.dart` · `lib/features/auth/presentation/forgot_password/forgot_password_screen.dart` |
| booking | `lib/features/booking/data/datasources/remote/booking_remote_data_source.dart` · `lib/features/booking/data/datasources/remote/booking_waitlist_remote_data_source.dart` · `lib/features/booking/data/repositories/booking_repository_impl.dart` · `lib/features/booking/data/repositories/booking_waitlist_repository_impl.dart` · `lib/features/booking/presentation/booking_cubit.dart` |
| checkout | `lib/features/checkout/presentation/checkout_cubit.dart` · `lib/features/checkout/presentation/checkout_screen.dart` |
| favorites | `lib/features/favorites/data/datasources/remote/favorites_remote_data_source.dart` · `lib/features/favorites/data/repositories/favorites_repository_impl.dart` · `lib/features/favorites/presentation/favorites_cubit.dart` · `lib/features/favorites/presentation/favorites_screen.dart` |
| home | `lib/features/home/data/datasources/remote/home_remote_data_source.dart` · `lib/features/home/data/repositories/home_repository_impl.dart` · `lib/features/home/presentation/home_cubit.dart` · `lib/features/home/presentation/home_screen.dart` |
| lounge_details | `lib/features/lounge_details/data/datasources/remote/lounge_details_remote_data_source.dart` · `lib/features/lounge_details/data/repositories/lounge_details_repository_impl.dart` · `lib/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart` · `lib/features/lounge_details/presentation/lounge_details/lounge_details_screen.dart` · `lib/features/lounge_details/presentation/lounge_details/room_details_screen.dart` |
| main | `lib/features/main/presentation/main_screen.dart` |
| my_bookings | `lib/features/my_bookings/data/datasources/remote/my_bookings_remote_data_source.dart` · `lib/features/my_bookings/data/repositories/my_bookings_repository_impl.dart` · `lib/features/my_bookings/presentation/booking_timeline_cubit.dart` · `lib/features/my_bookings/presentation/my_bookings_cubit.dart` · `lib/features/my_bookings/presentation/my_bookings_screen.dart` |
| notifications | `lib/features/notifications/data/datasources/remote/notifications_remote_data_source.dart` · `lib/features/notifications/data/repositories/notifications_repository_impl.dart` · `lib/features/notifications/presentation/notifications_cubit.dart` · `lib/features/notifications/presentation/notifications_screen.dart` |
| onboarding | `lib/features/onboarding/presentation/onboarding_screen.dart` |
| profile | `lib/features/profile/data/datasources/remote/profile_remote_data_source.dart` · `lib/features/profile/data/datasources/remote/support_remote_data_source.dart` · `lib/features/profile/data/repositories/profile_repository_impl.dart` · `lib/features/profile/presentation/edit_profile/edit_profile_cubit.dart` · `lib/features/profile/presentation/edit_profile/edit_profile_screen.dart` |
| search | `lib/features/search/presentation/search_cubit.dart` · `lib/features/search/presentation/search_screen.dart` |
| splash | `lib/features/splash/presentation/splash_screen.dart` |
| tournaments | `lib/features/tournaments/data/datasources/remote/tournaments_remote_data_source.dart` · `lib/features/tournaments/data/repositories/tournaments_repository_impl.dart` · `lib/features/tournaments/presentation/history/tournament_history_cubit.dart` · `lib/features/tournaments/presentation/history/tournament_history_screen.dart` · `lib/features/tournaments/presentation/live_match/tournament_match_cubit.dart` |




## Appendix — Dashboard checked source feature index

This index was generated from the inspected source tree at the baseline commit; it is a **discovery index**, not a statement every module is wired and enabled.

| Feature directory | Representative entry points (current dev) |
| --- | --- |
| analytics | `lib/features/analytics/data/datasources/dashboard_remote_data_source.dart` · `lib/features/analytics/data/repositories/dashboard_repository_impl.dart` · `lib/features/analytics/presentation/dashboard_cubit.dart` · `lib/features/analytics/presentation/dashboard_screen.dart` · `lib/features/analytics/presentation/lounge_stats_cubit.dart` |
| audit | `lib/features/audit/data/datasources/audit_remote_datasource.dart` · `lib/features/audit/data/repositories/audit_repository_impl.dart` · `lib/features/audit/presentation/audit_cubit.dart` · `lib/features/audit/presentation/audit_screen.dart` |
| auth | `lib/features/auth/data/data_source/auth_remote_data_source.dart` · `lib/features/auth/data/repositories/auth_repository_impl.dart` · `lib/features/auth/presentation/login/login_cubit.dart` · `lib/features/auth/presentation/login/login_screen.dart` · `lib/features/auth/presentation/profile/profile_page.dart` |
| bookings | `lib/features/bookings/data/datasources/booking_remote_data_source.dart` · `lib/features/bookings/data/repositories/booking_repository_impl.dart` · `lib/features/bookings/presentation/cubit/booking_cubit.dart` · `lib/features/bookings/presentation/pages/booking_history_page.dart` · `lib/features/bookings/presentation/pages/bookings_page.dart` |
| canteen | `lib/features/canteen/data/datasources/canteen_remote_datasource.dart` · `lib/features/canteen/data/repositories/canteen_repository_impl.dart` · `lib/features/canteen/presentation/canteen_cubit.dart` |
| categories | `lib/features/categories/data/data_source/remote/category_remote_data_source.dart` · `lib/features/categories/data/repositories/category_repository_impl.dart` · `lib/features/categories/presentation/categories/categories_screen.dart` · `lib/features/categories/presentation/categories/category_cubit.dart` |
| kyc | `lib/features/kyc/data/datasources/kyc_remote_data_source.dart` · `lib/features/kyc/data/repositories/kyc_repository_impl.dart` · `lib/features/kyc/presentation/cubit/kyc_cubit.dart` · `lib/features/kyc/presentation/pages/kyc_pending_page.dart` · `lib/features/kyc/presentation/pages/kyc_reviews_page.dart` |
| lounges | `lib/features/lounges/data/datasources/lounge_remote_data_source.dart` · `lib/features/lounges/data/repositories/lounge_payment_settings_repository_impl.dart` · `lib/features/lounges/data/repositories/lounge_repository_impl.dart` · `lib/features/lounges/presentation/cubit/extras_cubit.dart` · `lib/features/lounges/presentation/cubit/lounge_cubit.dart` |
| loyalty | `lib/features/loyalty/data/datasources/loyalty_remote_data_source.dart` · `lib/features/loyalty/data/repositories/loyalty_repository_impl.dart` · `lib/features/loyalty/presentation/cubit/loyalty_cubit.dart` · `lib/features/loyalty/presentation/pages/loyalty_page.dart` |
| marketing | `lib/features/marketing/data/datasources/marketing_remote_data_source.dart` · `lib/features/marketing/data/repositories/marketing_repository_impl.dart` · `lib/features/marketing/presentation/cubit/marketing_cubit.dart` · `lib/features/marketing/presentation/pages/marketing_page.dart` |
| offline_cashier | `lib/features/offline_cashier/data/repositories/cashier_conflict_repository_impl.dart` · `lib/features/offline_cashier/data/repositories/offline_cashier_repository_impl.dart` · `lib/features/offline_cashier/presentation/cashier_conflict_cubit.dart` · `lib/features/offline_cashier/presentation/offline_workspace_cubit.dart` · `lib/features/offline_cashier/presentation/offline_workspace_page.dart` |
| onboarding | `lib/features/onboarding/data/datasources/onboarding_remote_data_source.dart` · `lib/features/onboarding/data/repositories/onboarding_repository_impl.dart` · `lib/features/onboarding/presentation/cubit/onboarding_cubit.dart` · `lib/features/onboarding/presentation/pages/lounge_setup_page.dart` |
| payouts | `lib/features/payouts/data/datasources/payout_remote_data_source.dart` · `lib/features/payouts/data/repositories/payout_repository_impl.dart` · `lib/features/payouts/presentation/cubit/payout_cubit.dart` · `lib/features/payouts/presentation/pages/lounge_admin_payouts_page.dart` · `lib/features/payouts/presentation/pages/super_admin_payouts_page.dart` |
| permissions | `lib/features/permissions/data/data_sources/permissions_remote_data_source.dart` · `lib/features/permissions/data/repositories/permissions_repository_impl.dart` · `lib/features/permissions/presentation/cubit/permissions_cubit.dart` |
| pricing | `lib/features/pricing/data/datasources/pricing_remote_datasource.dart` · `lib/features/pricing/data/repositories/pricing_repository_impl.dart` · `lib/features/pricing/presentation/pricing_cubit.dart` · `lib/features/pricing/presentation/pricing_screen.dart` |
| requests | `lib/features/requests/data/datasources/requests_remote_data_source.dart` · `lib/features/requests/data/repositories/client_requests_repository_impl.dart` · `lib/features/requests/presentation/client_requests_cubit.dart` |
| reviews | `lib/features/reviews/data/datasources/reviews_remote_data_source.dart` · `lib/features/reviews/data/repositories/reviews_repository_impl.dart` · `lib/features/reviews/presentation/reviews_cubit.dart` · `lib/features/reviews/presentation/reviews_screen.dart` |
| rooms | `lib/features/rooms/data/datasources/room_remote_data_source.dart` · `lib/features/rooms/data/repositories/room_repository_impl.dart` · `lib/features/rooms/presentation/cubit/room_cubit.dart` · `lib/features/rooms/presentation/pages/room_management_page.dart` |
| shifts | `lib/features/shifts/data/data_sources/shift_remote_data_source.dart` · `lib/features/shifts/data/repositories/shift_repository_impl.dart` · `lib/features/shifts/presentation/shift_history/shift_history_screen.dart` · `lib/features/shifts/presentation/shift_management/shift_cubit.dart` |
| splash | `lib/features/splash/presentation/splash_screen.dart` |
| staff | `lib/features/staff/data/data_source/remote/staff_remote_data_source.dart` · `lib/features/staff/data/repositories/staff_repository_impl.dart` · `lib/features/staff/presentation/staff_management/staff_cubit.dart` · `lib/features/staff/presentation/staff_management/staff_screen.dart` |
| support | `lib/features/support/data/datasources/support_remote_data_source.dart` · `lib/features/support/data/repositories/support_repository_impl.dart` · `lib/features/support/presentation/faq_management_screen.dart` · `lib/features/support/presentation/lounge_owner_support_screen.dart` · `lib/features/support/presentation/policy_management_screen.dart` |
| system | `lib/features/system/data/datasources/system_remote_data_source.dart` · `lib/features/system/data/repositories/system_repository_impl.dart` · `lib/features/system/presentation/cubit/app_status_cubit.dart` · `lib/features/system/presentation/system_settings_cubit.dart` · `lib/features/system/presentation/system_settings_screen.dart` |
| tournaments | `lib/features/tournaments/data/datasources/tournament_remote_data_source.dart` · `lib/features/tournaments/data/repositories/tournament_repository_impl.dart` · `lib/features/tournaments/presentation/tournament_cubit.dart` · `lib/features/tournaments/presentation/tournament_matches_cubit.dart` · `lib/features/tournaments/presentation/tournament_participants_cubit.dart` |
| users | `lib/features/users/data/datasources/admin_management_remote_data_source.dart` · `lib/features/users/data/datasources/moderation_remote_data_source.dart` · `lib/features/users/data/repositories/admin_management_repository_impl.dart` · `lib/features/users/presentation/cubit/admin_management_cubit.dart` · `lib/features/users/presentation/cubit/moderation_cubit.dart` |

Edge Function handlers (source presence only): `supabase/functions/create-lounge-owner/index.ts`, `supabase/functions/create-lounge-staff/index.ts`, `supabase/functions/deactivate-lounge-admin/index.ts`, `supabase/functions/delete-account/index.ts`, `supabase/functions/reconcile-auth-disable/index.ts`, `supabase/functions/send-fcm-notification/index.ts`, `supabase/functions/send-system-announcement/index.ts`, `supabase/functions/update-user-location/index.ts`.

