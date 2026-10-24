# PlaySpot market and capability review — evidence pass 1

Scope: read-only research on 24 October 2026 against Mobile `dev` `e50e686503161df4ea8dca2f4b7947484b0041aa`, Dashboard `dev` `e111196f0ebaabe3a1ec39e4e2a2d094d388c621`, official vendor pages, and pinned public repository snapshots. This pass establishes what can be supported by inspected sources. It does **not** certify hosted schema parity, physical PC control, offline resilience, or production readiness. No third-party code was copied into PlaySpot.

## Business evidence and comparison boundary

The newer product directive reports seven operator responses; the unmerged System Atlas records four earlier responses. The underlying survey records and dates have not yet been reconciled. Both are qualitative discovery, not an estimate of Egyptian market share.

PlaySpot needs three distinct operating modes: booking requests with human confirmation while a lounge keeps its incumbent system; PlaySpot-native business operations with physical device control only after a separately verified local agent exists; and a vendor-neutral bridge only when the vendor provides an authorized, tested interface. A PlaySpot booking is not proof that PanCafe reserved or unlocked a device.

| Product/source | Documented capability | What it establishes for PlaySpot |
| --- | --- | --- |
| [PanCafe Pro official features](https://www.pancafepro.com/?page=features) | Server/client terminal sessions (including indefinite sessions), tariffs, cafeteria stock, cashier authorization, reporting, remote administration, and audio warnings. | A comparison target for daily cashier workflows. The feature list does not document a supported public integration API. |
| [Gizmo official product](https://gizmopowered.com/product) and [manual](https://www.gizmopowered.com/support/documentation) | POS/PC management, billing, remote management, security logs, and employee/shift reports. | Compare session/POS/shift flows; marketing statements do not establish integration compatibility or failure behavior. |
| [ggLeap official product](https://www.ggcircuit.com/ggleap) | PC booking, POS, client UX, memberships, and an advertised API. | Shows that documented vendor integration is possible in this market, but no PlaySpot–ggLeap authorization or API contract has been reviewed. |

## Open-source candidates — research only

The table distinguishes source inspection from README claims. License and code suitability require a full audit before any reuse.

| Repository | Inspected snapshot and evidence | Engineering conclusion |
| --- | --- | --- |
| [mosaiba/CyberCafeSystem](https://github.com/mosaiba/CyberCafeSystem) | `1ac7c75f` contains a C# server, PC client, raw TCP packets/heartbeat, SQLite, and `LICENSE.txt` declaring MIT. `CyberCafe.Core/Data/DatabaseManager.cs` seeds admin password `1234` with unsalted SHA-256; `CyberCafe.Client/Views/FormClient.cs` also accepts literal `1234` to exit. No test project was found in the inspected tree. | Useful to study local server/client boundaries; **unsuitable as a secure agent starting point**. The hardcoded credentials and password storage must never be copied. |
| [imransaadullah/cool-cafe](https://github.com/imransaadullah/cool-cafe) | `b44f728f` has FastAPI local server, PyQt PC client, optional global server, Prisma/Postgres, tests, `offlinequeue` sync worker, and local client queue. README says MIT, but no LICENSE file was found in this snapshot. `local_server/app/auth_deps.py` exempts many client-mutating endpoints from admin JWT; `client/services/offline.py` uses a JSON-file queue with IDs based on queue length. | A substantial architecture reference, **not an approved dependency**. Device identity, command authorization, duplicate/replay handling, persistence, and license provenance need deeper review. |
| [ziy4n47/gaming-cafe-system](https://github.com/ziy4n47/gaming-cafe-system) | `7c910b35` uses a cloud-only browser cashier model with no PC agent. `sql/002_create_sessions.sql` adds unique indexes for one open segment per PC/session. `004_auth_and_roles.sql` replaces early broad authenticated policies with staff checks. No license file or automated tests were found in the inspected tree. | Useful contrast for a booking/cashier-only mode and append-only thinking; it cannot prove physical device state. Final RLS and privileged helper grants require review. |
| [amosdavis/gaming-cafe-management](https://github.com/amosdavis/gaming-cafe-management) | README describes .NET/WinForms billing and an agent, while explicitly listing multi-station server, end-to-end tests, and secure communication as pending. | Research candidate only; README itself does not support treating it as a production-ready multi-station implementation. License and actual code review remain open. |
| [SimBoi/PyCyberCafe](https://github.com/SimBoi/PyCyberCafe) | README documents Python Windows scripts, static-IP targeting, timed access, PC locking/restart, and Task Scheduler/SYSTEM setup. | Demonstrates a simple local-control model, but security, recovery, licensing, and tests remain unverified; do not reuse device-control code. |
| [xAhmedAdel/Cafe-Management](https://github.com/xAhmedAdel/Cafe-Management) | README describes ASP.NET/SignalR server and WPF client with remote control and billing; its license badge says MIT. | Promising architecture reference. Verify the license file, implemented authorization, update process, and tests against code before treating README claims as proven. |

## PlaySpot capability matrix at current `dev`

`IMPLEMENTED BUT NOT FULLY VERIFIED` means the named client/server path exists; it does not claim a production-equivalent end-to-end pass.

| Capability | Classification | Source evidence and next gate |
| --- | --- | --- |
| Booking hold, quote, checkout | IMPLEMENTED BUT NOT FULLY VERIFIED | Mobile `lib/features/booking/data/datasources/remote/booking_remote_data_source.dart` calls `acquire_booking_hold`, `quote_my_booking_checkout`, and `create_my_booking_checkout`; related unit and backend tests exist. Recheck lost acknowledgments, expiry, duplicate attempts, RLS, and deployed schema. |
| Open Time business session | IMPLEMENTED BUT NOT FULLY VERIFIED | Canonical migration `supabase/migrations/20260928000014_open_time_sessions.sql` defines start/complete functions and snapshot columns. Dashboard `lib/features/bookings/data/datasources/booking_remote_data_source_impl.dart` calls start/close RPCs; merged [PR #80](https://github.com/salahaldensherief/Playspot_dashboard/pull/80) and [PR #82](https://github.com/salahaldensherief/Playspot_dashboard/pull/82) reject false-success close/start responses. `supabase/tests/p0_open_time_and_pricing_tests.sql` exists. Mobile financial corrections are separate Draft PR #75. Verify exact schema, timestamp billing, concurrency, ledger effects, and both clients together. |
| Canteen ordering | IMPLEMENTED BUT NOT FULLY VERIFIED | Mobile `booking_remote_data_source.dart` calls `place_canteen_order`; both clients have canteen UI/models. Confirm committed charge presentation, stock movement, partial collection, and ledger semantics with exact schema. |
| Shift opening, blind close, approval | IMPLEMENTED BUT NOT FULLY VERIFIED | Dashboard `lib/features/shifts/data/data_sources/shift_remote_data_source_impl.dart` calls `open_lounge_shift`, `blind_close_shift`, and `approve_shift`; shift authorization/reconciliation tests exist. Pilot two-cashier and offline reconciliation behavior. |
| Offline cashier queue and conflict review | IMPLEMENTED BUT NOT FULLY VERIFIED | Dashboard `lib/features/offline_cashier/` contains authority, encrypted journal, outbox sync, and conflict UI; 23 focused tests exist. Long disconnect, restart, replay, writer handover, and real shift-close pilot remain open. |
| Realtime booking/session views | IMPLEMENTED BUT NOT FULLY VERIFIED | Mobile booking datasource and Dashboard `booking_realtime_datasource.dart` subscribe to booking streams. Verify restart/reconnect ordering and stale-state recovery in a browser/device pilot. |
| Physical Windows PC control | MISSING FROM VERIFIED PLAYSPOT PATH | No independently validated Windows agent/server is in Mobile/Dashboard `dev`. [Mobile Draft PR #81](https://github.com/salahaldensherief/playspot_V2/pull/81) implements an isolated protocol simulator with local tests; it is not a PC controller or backend integration. A dashboard room state is not PC connectivity or lock state. |
| Vendor bridge to PanCafe/Gizmo | BLOCKED BY EXTERNAL DEPENDENCY | No authorized, verified API contract or production integration has been established for those vendors. Booking-only with human confirmation remains the honest coexistence mode. |
| Approved Dashboard presentation | VERIFIED WORKING AS BRANCH STATE | Dashboard `dev` retains the prior UI. The rejected visual redesign in [Dashboard PR #75](https://github.com/salahaldensherief/Playspot_dashboard/pull/75) was closed without merge. Browser usability and performance at a real lounge are separate validation tasks. |

## Target-product gap analysis and acceptance gates

This comparison is deliberately narrower than a claim that every feature is production-ready. A source path is evidence that an implementation exists; the right column names what still has to be proved.

| Target workflow | Current evidence | Gap and acceptance gate |
| --- | --- | --- |
| Incumbent-system coexistence without false reservations | PlaySpot booking/checkout paths exist; no verified PanCafe API was found in official research | Demonstrate a clearly labeled *request pending cashier confirmation* path and expiration/cancellation behavior. A customer success screen must not assert external inventory was reserved. Current end-to-end behavior needs inspection. |
| Native station operation | Room/session model and Dashboard cashier UI exist | Physical Windows lock/unlock, observed device state, pairing and revocation are missing from the verified path. Pass architecture review and lab simulator before coding a privileged agent. |
| Fixed and Open Time session finance | `start_open_time_session` / `complete_booking_session` paths, pricing snapshot migration and P0 SQL tests exist | Reconstruct **effective** schema, all later overrides, triggers and grants. Prove rounding, max duration, future reservation, concurrent start, duplicate close and authoritative end timestamp. Mobile PR #75 remains Draft. |
| Canteen during a running session | `place_canteen_order` and canteen models/UI exist | Show committed canteen obligations while time charge is still unfinalized, and show actual collections separately. Verify stock, ledger and partial payment results across clients. |
| Cashier shift and offline operation | Dashboard has shift RPC calls, encrypted journal, writer lease, outbox and conflict UI | Run two-cashier partition/restart/replay tests against isolated backend. Prove a lost ACK does not create duplicate cash or silently discard an uncertain operation; reconcile on shift close. |
| Real-time operational view | Both clients subscribe to booking data; Dashboard scheduler safety PR #77 is merged | Verify browser and mobile restart/reconnect, stale-result suppression, expired alerts and canonical cashier close. Test 6/20/40 mixed stations in Arabic/English with permissions and conflicts on approved UI. |
| Vendor bridge | Earlier PRs/docs discuss bridge contracts | External API, authorization, device observation, idempotent command/booking semantics and vendor failure behavior are unverified. Keep bridge unavailable until a vendor-specific contract and sandbox exist. |

**Priority rule:** fix already-confirmed financial and stranded-session defects first; then validate the cashier/offline pilot; only then choose a local control implementation. This avoids replacing working booking/POS code with a device system whose trust and recovery behavior is not yet established.

## Priority and next verification

1. **P0 financial integrity:** reconstruct the effective Open Time schema, triggers, functions, grants, RLS, and ledgers in a disposable environment; run pricing snapshot, rounding, concurrent start/duplicate close, canteen, partial payment, future reservation, and shift tests before financial PR integration.
2. **P0 operations safety:** verify canonical cashier close remains reachable and sessions do not strand after reconnect/restart; retain the merged scheduler safety fix.
3. **P1 cashier pilot:** test the approved Dashboard UI with mixed PC/PlayStation rooms in Arabic and English, including 6/20/40 stations, permissions, conflicts, alerts, and performance. Do not revive the rejected redesign.
4. **P1 offline pilot:** test two cashiers, long network loss, outbox replay, conflict review, and reconciliation against isolated realistic records.
5. **P2 local architecture:** the isolated coordinator/agent simulator tests spoofing, replay, restart, heartbeat and corrupt state on [Mobile Draft PR #81](https://github.com/salahaldensherief/playspot_V2/pull/81). Split brain, clock drift, revocation, secure transport/storage, updates and rollback remain open before any device-control code.

The [local operations architecture and threat model](PLAYSPOT_LOCAL_OPERATIONS_ARCHITECTURE_20261024.md) records the conditional branch-coordinator recommendation, alternatives, trust boundaries and simulator/lab acceptance gates. A simulated agent has been implemented and locally tested on Mobile Draft PR #81; no physical PlaySpot device agent has been implemented or tested.

## Small-increment delivery roadmap

| Increment | Dependency and risk | Acceptance evidence | Rollback / release boundary |
| --- | --- | --- | --- |
| Open Time presentation and close-path correction | High financial risk; Mobile PR #75 plus exact effective-schema reconstruction | Running canteen liability visible separately from provisional time; completed duration from authoritative timestamps; reconnect/restart tests; pricing/rounding/max/concurrency/duplicate close/partial payment/RLS/ledger fixtures pass | Keep financial branch Draft until exact-schema results; no production migration or collection action. Revert client display independently if it misrepresents committed amounts. |
| Canonical cashier-close operational proof | Dashboard scheduler safety is already on `dev`; backend close/permission contract required | Expired sessions remain visible and authorized cashier can close once, including after reload/reconnect; unauthorized role cannot close | Disable only the affected UI action if server contract breaks; do not restore generic auto-completion. |
| Booking-only coexistence pilot | No vendor API; medium customer-expectation risk | Request, cashier acceptance/rejection, expiry and customer status are explicit; conflicting incumbent inventory is never labeled reserved | Restrict pilot to manually confirmed venues; withdraw request intake while preserving prior booking records. |
| Offline cashier two-writer pilot | Writer lease and exact backend fixtures; high money/recovery risk | Long partition, restart, lost ACK, replay, takeover, conflict review and shift reconciliation complete without duplicate collection | Stop new offline permits, drain/review outbox and reconcile before any writer handover; do not delete uncertain journal entries. |
| Local device-control simulator, then lab prototype | Architecture/threat review and explicit authorization before hardware use; high security risk | Typed protocol, pairing/revocation, fencing, crash recovery and signed rollback tests pass; observed PC state is distinct from requested state | Revoke device identities and disable coordinator commands; cashier-only operations remain available with manual procedures. |
| Browser usability pilot of approved Dashboard | Stable cashier workflows and representative fixture data; medium UX risk | Arabic/English 6, 20 and 40 mixed PC/PlayStation stations; alerts, permissions, conflicts and performance recorded on the real Flutter Web UI | Ship focused visual fixes through separate PRs; preserve the accepted `dev` design while a new design is reviewed. |

Each increment needs its own head SHA, reproducible test output and a reviewed PR targeting `dev`. A passing mock or browser screenshot is evidence only for the behavior it exercised. Financial, device and vendor integration work must not inherit approval from documentation merges.

This pass involved source reads only. No third-party program was executed, no PlaySpot test suite was rerun specifically for this report, and no production database or hardware was touched. Existing CI passing on unrelated final heads must not be represented as completion of these open verification gates.
