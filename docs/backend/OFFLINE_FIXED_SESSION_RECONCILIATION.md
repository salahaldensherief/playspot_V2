# Offline fixed reservations and session lifecycle

Review sources only. No hosted migration or dev/main merge has been performed.
Native fixtures exercise PostgreSQL 17.11 on synthetic data at loopback port 55439.

Load `active_super_admin_boundary.sql`, `offline_walk_in_customer_policy.sql`,
`partial_cash_collection.sql`, `cashier_writer_availability.sql`,
`offline_fixed_session_capacity.sql`, `offline_fixed_session_reservation.sql`,
`offline_fixed_session_transitions.sql`, `offline_canteen_reconciliation.sql`,
then `offline_cash_reconciliation.sql`. Load the verified minimal schema and
captured hosted price/policy triggers first when running the isolated fixture.

The coordinator supports ordered reserve/start/items/cash/close requests. Every
request retains Auth actor, venue, device, permit, own shift, booking and event
identity. Reservations need `bookings.manage`; start/items/close need
`sessions_control`; collecting cash independently needs billing eligibility.
Session-only permission can start a reservation without acquiring permission to
create or reschedule bookings. Private proof rows are transaction-bound and
inaccessible to clients; success removes them and failure rolls them back.

A walk-in has no registered customer identity. The first-customer prepaid policy
now exempts account-free bookings only for an eligible actor with booking authority
in an approved venue. A registered first customer still must prepay. A customer
cannot evade that policy by supplying a null identity. Cash-disabled venues remain
protected. Customer names and optional phone fields have type/length validation.

Reservation times are whole UTC epoch minutes, positive intervals of at most
24 hours, at or after the recorded event's minute. Their timezone must exactly
match the venue's verified `lounges.timezone`. Local/UTC round trips and elapsed
minutes must agree; DST crossing or ambiguous intervals become retained conflicts
for review. Overnight intervals are supported. The source uses the captured hosted
`quote_booking_price` contract, checks the actual post-trigger total, and rejects
price drift. Device fixed-price math uses actual minutes and exact cent rounding;
open-time billing quantum is a separate, unfinished contract.

Room eligibility, venue scope, exact own open shift and existing tournament
allocation are checked. Room rows are locked before booking rows. A running session
continues to block a new start after its planned end. The GiST exclusion constraint
protects overlap; adjacent intervals are allowed. Scheduling a tournament concurrently
and legacy RPC lock ordering still need separate review.

The immutable `quoted_session` records room, timezone, planned start/end, started
milliseconds and paid cents, alongside `quoted_total_minor`. After applying a
session command the server compares the canonical result to that saved snapshot
inside the same rollback boundary. Rescheduled bookings, changed balances, missing
snapshots or fabricated event times cannot commit a transition. The dashboard checks
the receipt independently before persisting an acknowledgement and removing a queue
entry. `session_receipt` contains canonical status, shift, UTC planned/capacity
milliseconds, actual timestamps and total/paid/due/status. Timestamp strings retain
microseconds; exported capacity uses floor to integer milliseconds for Dart/Hive.

Closing never collects or marks a debt as paid. New server-owned
`cashier_closed_at`, `cashier_booking_timezone` and stored generated
`cashier_capacity_period` separate actual occupancy from agreed billing. Closing
early releases remaining capacity without altering planned end, generated duration
or price. Historical occupancy remains protected. Legacy completed rows without
trusted close facts retain their whole planned capacity. Maintenance remains
maintenance after closing. Direct edits to close/timezone facts are denied.

`offline_fixed_session_capacity.sql` replaces the existing named booking exclusion
constraint with one over the new capacity range. This is a table/index deployment
operation, not a lightweight hot fix: inventory existing/null dates and times,
column types, conflicting data, all trigger/RLS/ACL behavior and lock ordering;
plan table rewrite/index rebuild locks and update discovery/read adapters that still
use `booking_period`. Those adapters otherwise remain conservatively unavailable
after an early close. Do not automatically apply this source to production.

Verification: 53 native cases passed. Cases include first-customer/permission
boundaries, typed customer fields, overlapping/adjacent bookings, tariff changes,
room scope/status, cash policy, malformed intervals, overnight/DST handling,
existing tournaments, session-only start permission, snapshot changes, late/early
starts, overdue occupancy, shift ownership/closure, early close and historical
capacity, microseconds, maintenance, cash-trigger repricing rollback, a complete
five-command flow and replay after shift closure. Two independent connections
actually wait on the writer lock and commit one reservation for duplicate requests.
Canonical active super admins can reconcile the lifecycle and partial cash without
staff grant rows. Their effective permission snapshot and private booking proof use
the same verified admin boundary. Banned/disabled/deleted identities do not inherit
those privileges. Separate writer tests cover both canonical role and platform-list
membership, membership removal and actual profile/Auth revocation lock waits.

Run with `PLAYSPOT_NATIVE_PG_PORT=55439`:
`node supabase/tests/offline_fixed_session_reconciliation.test.mjs`.
Optional `PLAYSPOT_FIXED_CONTRACT_EXPORT` exports the complete synthetic five-command
operation/response flow to UTF-8 JSON for the dashboard's real encrypted Hive tests.
The fixture supplies synthetic permissions/Auth and long historical permit windows
for DST dates; it does not reproduce all hosted audit/moderation/notification/loyalty
triggers, production RLS or credential storage. Earlier sources separately pass
47 partial-cash, 41 writer, 25 envelope and 34 item-order native cases.

Release remains blocked on immutable permit renewal/reassignment, canonical cache
bootstrap, authenticated/logout binding, shift lifecycle/reconciliation, conflicting
operation review, real cashier read/action adapters and hosted deployment validation.
Open-time/extensions, combos, discounts, mixed payments/refunds, old canteen/KYC
overloads and the broader backend baseline remain incomplete. Existing experimental
commands missing quotes or snapshots must be retained for explicit review.
