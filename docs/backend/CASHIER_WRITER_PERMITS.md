# Immutable cashier permits and renewal

Review source only. No hosted migration or SQL write was performed. Load
`cashier_writer_permits.sql` after the verified permission/admin helpers and before
`cashier_writer_availability.sql`. The cash/fixed-capacity sources use its private
historical-grant helper; deploy these contracts together only after schema review.

`refresh_cashier_writer` protocol version 2 returns actor, venue, device and permit
UUIDs, immutable issued/expires milliseconds, effective permission booleans,
current eligible-account/venue flags, venue timezone, requested connection mode,
server milliseconds, heartbeat deadline and the venue's applied sequence.
Online heartbeat is 90 seconds; offline heartbeat equals server time. Server time
is captured after acquiring the writer lock so a waiting renewal cannot return an
already-stale heartbeat. Permissions use the same canonical active-super-admin
boundary as issuance, booking proofs and reconciliation.

The writer remains assigned to one account/device. A live unchanged grant is
reused without changing its original 24-hour window. Expiry or a changed effective
permission map inserts a fresh grant and changes only the current pointer/window
and heartbeat. `private.cashier_writer_permits` denies client reads/writes and
rejects UPDATE/DELETE, including accidental privileged mutations. Audit history
is retained; no automatic cleanup, reassignment or grant backfill is implemented.

Reconciliation locks the current writer but validates the incoming **original**
grant. Actor/device/venue must still match the assigned writer. The original grant
must have issued that operation's permission and contain its occurrence time.
Current Auth/profile, approved venue, effective permission and own open shift are
checked independently. An expired historical grant can reconcile a valid earlier
event after renewal; it cannot authorize a later event or borrow new permissions.

Sequence and conflict boundaries are venue-wide across grant generations. A new
permit cannot reset the counter, skip a conflict or manufacture a second financial
receipt. Exact response-loss retry remains bound to the original operation JSON
and stored permit. Before creating the new venue-sequence unique index, inspect
existing receipts for duplicate historical sequences. Do not delete or rewrite
financial records to make an index succeed.

Pre-versioned writer rows without the original grant fail closed with
`CASHIER_PERMIT_RECORD_MISSING_OR_CHANGED`. Their previous window must not be
reconstructed from a mutable latest heartbeat. Any deployed legacy writer or
client pending operations need explicit reconciliation before protocol activation.

23 cases passed on native PostgreSQL 17.11, including observed two-connection lock
waiting and exactly one renewal generation. Writer/cash/items/fixed-session suites
also passed 41/25/34/53 cases with the shared source loaded. Run from the backend
repository with `PLAYSPOT_NATIVE_PG_PORT=55439`:
`node supabase/tests/offline_permit_renewal.test.mjs`.

Optional `PLAYSPOT_PERMIT_CONTRACT_EXPORT` writes only synthetic identities: the
current response comes from the actual native RPC; the previous response is
constructed from the immutable historical grant to represent an earlier cached
response, and the pending reservation is a synthetic original-grant event.
This fixture does not prove production Auth, secure-key storage or UI integration.
Event time/device UUID are not cryptographic or hardware attestation.

Release still needs canonical resource bootstrap, real cashier read/action and
heartbeat adapters, shift/conflict review, explicit writer reassignment, hosted
schema/RLS/trigger verification and coordinated availability discovery/quote/hold
deployment. Independent multi-device operation remains unsupported without a
separate local coordinator.
