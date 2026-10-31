# 20:00 peak-hour operational stress test

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Result

**PARTIAL — constituent concurrency tests executed; composed real-operator scenario not executed.** All 59 native PostgreSQL suites passed, including actual lock-wait tests for competing future holds, offline reservations, wallet debit/replay, refunds/topups, payout allocation and shift closure against collection. Audit probes exposed unpaid cash start mismatch and inferred extension collection. These results do not establish a full 20:00 shift pass.

## Reproducible scenario and fixtures

Use an isolated disposable Supabase-compatible database with exact reviewed schema, synthetic Auth users and two lounges A/B. Venue A: eight resources R1–R8; R1/R2 occupied with paid/unpaid fixed sessions, R3 open time, R4 reserved at20:30, R5–R8 free. Seed a current shift, catalogue stock2, owner, cashier, read-only employee, second cashier and three customers. Use a controlled clock at20:00 Africa/Cairo and repeat across midnight/DST. Fixture identities are synthetic; do not seed hosted demo or production.

| Step | Concurrent action | Expected invariant / visible outcome |
|---|---|---|
| 1 | Two walk-ins and three online requests race for R5/R6 | At most one authoritative allocation per room/window; rejected contenders visible, requests retained |
| 2 | R2 requests +30m while R4 starts at20:30 / future reservation on same resource | Extension cannot cross reserved capacity; no price/payment writes on conflict |
| 3 | Cashier explicitly collects one outstanding balance, repeated after dropped ACK | One receipt/collection, original result recovered, no extra debit |
| 4 | Employee without sessions_control adjusts/completes R1 | Server denial and no inventory/finance/audit-success write |
| 5 | Approval/checkout commits then network response is lost | UI pending/unknown; recover original booking/command; never report definite failure from timeout |
| 6 | Shift close races collection, pending outbox and cashier handoff | Locked transition, consistent actual cash, denied/deferred/explicit handoff; no hidden loss |
| 7 | Browser reload/offline/reconnect during operations | Persisted journal/receipt survives where offline supported, stale operations do not acquire new capacity |
| 8 | Attempt same resource from lounge B / wrong branch | No records, notifications or controls cross tenant boundaries |

## Commands actually executed

`npm ci --prefix supabase/tests/runtime`; each `node supabase/tests/*.test.mjs` with PLAYSPOT_NATIVE_PG_PORT=55439 in a new loopback-only PostgreSQL17.11 cluster. Each suite creates and drops its own randomly named synthetic database. Exact per-suite exit codes/logs: evidence/native-results. Examples: future_booking_hold (9 checks), offline_fixed_session_reconciliation (54), wallet_concurrency (5), payout_funds_custody (17). Run audit probes with `node supabase/tests/launch_v2_cash_start.probe.mjs` and `node supabase/tests/launch_v2_extension.probe.mjs` using the same guard. Probe outputs are defect reproductions, not feature passes.

The existing standalone room_active_session_concurrency.py and native .sql scripts were inspected but not executed; their named fixture setup must be prepared separately. No full migration-chain/production-schema restore or composed scenario harness was executed. PGlite attempts had fixture incompatibilities; native retry passed all 59 suites. See12.

## Operator usability review and human test

Source shows current sessions rail/details/actions, request feed, next-booking details and separate creation/payment workflows. ClientRequestsCubit retains request scope/pending actions and preserves newer snapshots in tests. Dashboard PR67 patch is already equivalent in dev. One grouping test fails after explicit-end authority changed; do not claim staff prioritization is verified.

AudioService uses audioplayers with web asset fallback, mute preference and urgent loop; requests choose one alert per incoming batch. There is no evidence here that browser autoplay/user-gesture permissions were satisfied. This is sound/tone support, not typography. Manually test a clean browser before/after first user gesture, muted mode, fresh vs already-known requests, tab backgrounding and an urgent loop that stops when addressed. Do not rely solely on sound.

Two venue employees should execute the scenario in AR and EN at desktop and narrow/tablet width. Record clicks/navigation, missed requests, decision errors, recovery comprehension, next reservation visibility, time to acknowledge and support intervention. Proposed experimental operator gate: every critical task completed without booking/financial integrity incident, no lost requests, clear pending/error states and no unexplained total; timing SLA chosen with partners, not an industry benchmark. Capture observed times and actual browser/device/build versions. A headless widget pass does not count as this human pass.

Launch blockers: PS-002/004/005/008, exact app/backend version parity, complete role/Storage/Realtime acceptance and the human rehearsal. Remedies and ordered gates in13/14.
