# Device writer and online venue availability

`supabase/repairs/cashier_writer_availability.sql` is coordinated release source,
not hosted SQL that has been applied. It depends on the existing private effective
permission helper and the reviewed active-super-admin boundary.

The first authorized cashier claims a venue for one account/device. Refreshing a
heartbeat renews a 90-second online availability deadline and a 24-hour offline
authorization window. An expired heartbeat never lets a second independent device
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
to verify this boundary. The actual apply_offline_cashier_operation RPC remains to
be implemented and reviewed, so this source is not a complete deployment.

Thirty-one cases passed on local PostgreSQL 17.11, including actual insert/update
rejection and two independent connection claims with observed lock waiting.
Discovery/quote/hold responses still need wiring to the availability helper so the
UI does not advertise stale availability. Existing production triggers, payment
flows and old migrations have not been tested together with this source.

Before release, coordinate database deployment, client writer bootstrap/heartbeat,
offline cache and outbox reconciliation, permit policy, explicit reassignment and
conflict review. No production migration or live mutation was executed here.
