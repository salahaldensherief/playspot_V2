# Offline rollout compatibility review — 2026-10-04

This is verification of review sources, not an offline-production release. Read-only hosted inspection confirms `refresh_cashier_writer` and `apply_offline_cashier_operation` are absent. Dashboard has encrypted Hive journal, secure-storage key vault, device preferences in GetStorage, local commands and transport layers, but no presentation consumer/bootstrap currently opens the repository through `CashierStoreFactory`. Initializing dependency injection alone does not enable offline cashier operations.

Native PostgreSQL 17 reruns passed:
- 53 fixed-session reconciliation checks with the newly deployed room/session guards loaded.
- 25 cash reconciliation checks.
- 34 item reconciliation checks, including actual concurrent database lock waits.
- 25 permit-generation/renewal checks.

The current-guard compatibility fixture has an explicit optional `PLAYSPOT_ROOM_GUARD_SQL` hook. The maintenance/close scenario first proves the guard rejects changing an active room to maintenance, then temporarily bypasses that one trigger in the disposable fixture to simulate a legacy inconsistent row. The existing assertion that close preserves maintenance remains intact; production triggers were never disabled. A test fixture cannot create the now-forbidden state through ordinary writes.

Reproduce the integrated 53-case check with `PLAYSPOT_NATIVE_PG_PORT=55439`, `PLAYSPOT_ROOM_GUARD_SQL` pointing to `supabase/migrations/20261004035454_room_active_session_invariants.sql`, and `node supabase/tests/offline_fixed_session_reconciliation.test.mjs`. The owned cluster uses local-only `playspot_fixture` credentials and disposable databases. The other three native suites use the same port with their own minimal schemas. Fixtures do not mirror every hosted moderation/audit/notification/loyalty trigger or Auth session revocation.

Read-only hosted preflight found the existing GiST booking-period exclusion constraint and zero overlapping retained booking pairs under the proposed initial capacity period. Canonical helper names, payment uniqueness and required booking/timezone columns exist. These findings support further review; they do not authorize applying unreviewed source files or establish a finished UI.

Remaining coordinated work: create a reviewed new migration from the source contracts; match current hosted price/ledger/trigger definitions; provide an atomic scoped bootstrap; install writer heartbeat and discovery availability adapters; wire local reserve/start/items/cash/close and ordered reconciliation into the real cashier UI; retain conflict review and expired/closed-shift cases; verify disconnect/restart/reconnect with isolated end-to-end records. Open-time and advanced pricing remain unsupported by these fixed-session sources. Cross-device reassignment and LAN multi-device coordination remain separate work.

No hosted operations, writers, leases, cash receipts, inventory or booking-capacity constraint were changed in this review.
