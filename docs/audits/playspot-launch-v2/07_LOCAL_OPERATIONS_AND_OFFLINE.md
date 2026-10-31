# Local operations and offline

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Current reality

The Dashboard has more than caching. initOfflineCashierDI initializes platform-appropriate Hive storage, secure key vault, device preferences, conflict repository, journal/store factory and workspace. lounge_admin_routes exposes OfflineWorkspacePage. EncryptedCashierJournal atomically persists one aggregate containing projection/outbox/receipts and flushes. Losing the key with an existing box fails closed. Factory identity epochs close journals on sign-in/sign-out/account change. LocalCashierCommands supports reserve/start/addItems/collectCash/close, validates permit/scope and monotonically sequences commands. Outbox synchronization verifies canonical receipts; authority/bootstrap/heartbeat/release transports exist.

Native suites executed: bootstrap, partial cash, stock reconciliation, fixed sessions, immutable permit renewal, writer handover/availability, conflict review, future coverage and online hold barrier. Fixed-session suite reports54 checks including real concurrent reservation replay and online/offline lock order. This validates reduced synthetic contracts, not all production triggers or a durable browser/Windows POS.

| Capability | Evidence classification | Limit |
|---|---|---|
| Cached reference/profile data | IMPLEMENTED BUT UNVERIFIED operationally | Stale cache cannot authorize booking or prove paid totals |
| Locally calculated timers | IMPLEMENTED BUT UNVERIFIED | Server-start authority remains necessary; clock shift/background scheduling need device tests |
| Persisted fixed-session/cash/item commands | PARTIAL | Journal implementation + fixture checks; crash/reopen/quota/key-store acceptance absent |
| Exclusive authority / recovery queue | PARTIAL | Writer permits/receipts exist; multi-tab and real reconnect not tested |
| Full local authoritative operation | PARTIAL | Explicit permit/coverage supported, open-time/extensions/advanced pricing not proven as offline commands |
| Windows Local service | MISSING as a verified production runtime | Mock Windows connector is in-memory hardware protocol only |
| Cloud reconciliation | IMPLEMENTED BUT UNVERIFIED end-to-end | Conflict outcomes tested synthetically; real full-schema replay needs rehearsal |

## Safe operation boundaries

Online normal Native operations use cloud authority. When disconnected without a valid unexpired scoped permit/bootstrap, show cached state read-only and stop new reservation, start, financial and inventory writes. With a valid permit, allow only supported commands for the explicitly covered resources/time/shift/actor/device; persist before presenting a local receipt, label cloud reconciliation pending. Unsupported pricing, open time, extension, mixed payments, refunds and shift reassignment must stop unless separately verified. Never convert optimistic local state into a confirmed online marketplace booking from stale inventory.

On reconnect, drain in order with original IDs/fingerprints; verify exact actor/tenant/permit-generation/canonical receipt, preserve conflicts and unsynced evidence, and block unsafe release/reassignment. A lost ACK is unknown, not failed. Existing bookings and debt survive commercial expiry and logout; never delete a journal to repair an error. Browser key retention and service-worker/cold-start asset availability remain untested.

## Architecture options

| Option | Benefit | Cost / authority rule | Recommended phase |
|---|---|---|---|
| A limited offline fallback | Small support burden; cached visibility | Stop writes safely when authority absent | First online pilot baseline |
| B Windows service + durable journal | Survives browser lifecycle; controlled local transport | Installer/signing/update/backup/auth/CORS/TLS/device lifecycle and crash recovery required | Isolated proof of concept after finance fixes |
| C local authority for assigned resources | Can keep defined operations running | Exclusive resource/window/permit ownership; cloud cannot sell that partition concurrently | Only after conflict and expiry evidence |
| D hybrid | Reuses cloud discovery plus local continuity | Explicit routing, generation/lease changes and reconciliation; never two authorities | Long-term, incrementally from existing writer protocol |

Do not conflate a Windows connector with Flutter Web offline readiness. Browser secure storage, IndexedDB/Hive durability, cold-start assets and operator UI remain separate. Hardware execution cannot own financial truth.

## Small isolated POC task

Reuse protocol2 fixtures/journal model. Start with one venue, two fixed-rate resources, a single writer and mock cloud transport. Kill process after journal flush and before ACK; restart and replay same command, proving one receipt/financial effect. Inject clock rollback, expired permit, changed generation, wrong tenant/device, full disk, lost encryption key and concurrent cloud allocation. Verify explicit blocked/pending states and auditable conflict resolution. No real vendor/hardware/venue service, no live migrations. Acceptance is crash-safe exactly-once effects under deduplication with one authoritative writer, not exactly-once network delivery. PS-009 remains open until browser/device and full-schema validation.
