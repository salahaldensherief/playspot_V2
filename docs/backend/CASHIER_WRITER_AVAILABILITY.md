# Device writer and online venue availability

`supabase/repairs/cashier_writer_availability.sql` is coordinated release source,
not hosted SQL that has been applied. Load `cashier_writer_permits.sql` before it,
after the existing private effective permission helper and the reviewed
active-super-admin boundary.

The first authorized cashier claims a venue for one account/device. Refreshing a
heartbeat renews only a 90-second online availability deadline. A live permit keeps
its original 24-hour window and permission snapshot. Expiry or changed effective
permissions issue a new immutable permit without resetting the venue sequence.
See `CASHIER_WRITER_PERMITS.md`. An expired heartbeat never lets a second independent device
take over: that could collide with unsynchronized work on the first device.
An explicit reviewed release/reassignment flow is still required. LAN multi-device
coordination is not provided by this table or by the client's in-process lock.

The venue must be approved, active and manually open to accept online customers.
The writer's Auth identity/profile/current effective session permission must remain
eligible. Explicit offline mode closes availability immediately when communicated;
an uncommunicable internet failure is detected after the heartbeat deadline.
The interval is bounded, not instantaneous. Resource reconciliation must account
for any booking accepted during that detection interval.

The booking trigger checks actual room ownership and gates insertion, confirmation
and capacity-affecting updates on the managed venue. It permits cancellation and
completion. A cashier role alone cannot bypass an offline gate. Only a private,
transaction-bound proof created by the reviewed reconciliation RPC can authorize
such insertion. The client cannot write writer rows or forge that proof; a committed
proof cannot authorize a later transaction. Tests create proofs as fixture admin
to verify this boundary. The actual apply_offline_cashier_operation RPC has separate
cash, item-order and fixed-session fixtures; none of these sources are deployed.

Writer refresh, capacity-affecting booking writes and offline reconciliation now
share a transaction-scoped advisory lock for the venue, acquired before writer
row locks. This also fences a first claim while no authority row exists. The
booking guard additionally locks an existing writer row in share mode, so direct
administrative row changes cannot race its availability check. Availability uses
the wall clock at evaluation time, including after lock waits; statement-start
time could admit a lease that expired while a booking waited.

The prior source was reproduced on native PostgreSQL: a competing customer insert
completed while an explicit offline refresh remained uncommitted. It now waits
and rejects after that refresh commits. The reverse ordering preserves the
already accepted booking before closing the venue; it does not erase capacity.

These entry points require READ COMMITTED. REPEATABLE READ and SERIALIZABLE are
explicitly rejected with `CASHIER_REQUIRES_READ_COMMITTED`, rather than accepting
an unverified older snapshot that might miss a newly claimed writer. Production
RPCs that lock an existing booking before this guard, or multi-venue bulk writes,
still need full-schema lock-order review. The local fixture does not establish
that all legacy production paths are free of deadlocks; failures must roll back
atomically and be retried through their idempotent contract.

Fifty-one writer cases passed on local PostgreSQL 17.11, including both directions
of booking/offline transitions, first claims, observed lock waiting, heartbeat
expiry during a wait, current-time evaluation in a long statement and rejection
of unverified isolation levels. All six affected native suites passed 235 cases:
51 writer, 25 cash reconciliation, 34 canteen reconciliation, 53 fixed sessions,
25 permit lifecycle and 47 partial cash collection. Permit cases include both
orderings of real offline reservation and writer refresh, with one persisted
reservation and sequence advancement.

The lock observer is a separate fixture-admin connection. Customer/employee
connections retain their tested roles; restricted `pg_stat_activity` visibility
must not be mistaken for lack of contention.

Discovery/quote/hold responses still need wiring to the availability helper so the
UI does not advertise stale availability. Existing production triggers, payment
flows and old migrations have not been tested together with this source.

Before release, coordinate database deployment, client writer bootstrap/heartbeat,
offline cache and outbox reconciliation, explicit reassignment and
conflict review. No production migration or live mutation was executed here.
