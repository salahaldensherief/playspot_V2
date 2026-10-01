# Partial cash collection — coordinated release source

`supabase/repairs/partial_cash_collection.sql` defines
`collect_booking_cash_partial(p_booking_id uuid, p_shift_id uuid,
p_amount_minor numeric, p_operation_id uuid) -> jsonb`.
It is reviewed source, not an applied migration or live endpoint.

Each request uses a positive integer amount in minor currency units and an operation
UUID. The authenticated cashier must be active, unbanned, have a surviving Auth
identity and effective billing permission in an active approved venue. The exact
shift must be open, belong to that cashier and venue, and have no conflicting staff
identity. A super-admin role does not exempt the own-shift requirement.

The booking lock serializes competing amounts. The server uses the booking's final
total and verified cash payment aggregate, rejects manual/unverified/mixed/refunded
or paid-out aggregates, and appends only the newly collected amount to shift payments.
The existing platform commission policy and financial trigger govern the aggregate.
Closing a session and collecting money remain separate: completed status is retained.
An unsettled open-time session requires finalization before collection.

A private operation receipt serializes concurrent replay and binds its UUID to
actor, booking, shift and amount. The receipt, payment aggregate, cash ledger and
booking payment status commit together. A successful retry after shift closure
returns the original receipt; disabled accounts or revoked billing eligibility
cannot retrieve it. Changing any bound parameter is a replay conflict.

The private payment trigger prevents older full-payment/wallet/refund code from
overwriting a booking controlled by these receipts outside the canonical path.
This intentionally requires coordinated client/server rollout: mixed-method topups,
refunds, payout lifecycle, deposits and alternative collection routes need a reviewed
compatible contract before this API is enabled. The source does not silently use
those older paths. Offline device permits and sequencing are separate requirements;
this financial RPC alone does not authorize an offline device or reconcile its queue.

## Verification

44 tests passed in native PostgreSQL 17.11 on the isolated loopback fixture cluster,
including real independent connections demonstrably waiting on row locks for:

- same-operation simultaneous retry;
- distinct operations competing for the remaining amount;
- shift closure ahead of collection;
- one operation UUID attempted against two bookings.

The suite also verifies account/venue/shift eligibility, whole minor units, invalid
totals, overpayment, completed-status preservation, exact incremental shift entries,
late-write rollback, response-loss replay, privilege boundaries and legacy aggregate
overwrite rejection. Run with `PLAYSPOT_NATIVE_PG_PORT=55439`:
`node supabase/tests/partial_cash_collection.test.mjs`.

Fixtures reproduce the financial calculation and closed-shift guards using minimal
tables. Hosted audit/RLS, Auth session revocation, UI behavior and the full production
schema/deployment chain are not proven. No hosted database write was performed.
