# Retained-token booking boundary

The observed hold and checkout RPCs checked only `auth.uid()`. A banned actor
could acquire a hold in the isolated PostgreSQL reproduction. This can consume
capacity even before checkout. Tokens can remain usable after profile suspension
or Auth deletion, so a JWT identity alone is insufficient.

`20261010134409_eligible_booking_hold_and_checkout_actor.sql` applies a shared
private guard to `acquire_booking_hold`, `quote_my_booking_checkout` and
`create_my_booking_checkout` before locks, quotes or writes. It requires an
existing Auth identity and an explicitly active, unbanned profile. The helper is
not executable by clients. Existing RPC signatures, financial/capacity bodies
and grants remain intact. The migration refuses an unknown entry-point body and
handles CRLF/LF source text; reapplication cannot duplicate its guard.

Validation: the observed baseline accepts a banned hold; the new suite verifies
nine authorization/idempotency cases, including empty persisted hold/booking
tables after denials. The full checkout/pricing/canteen fixture suite also runs
with this guard applied and verifies 24 cases using the real checkout bodies.
All accounts in these tests are SQL fixtures; this is not real Auth/UI E2E.

Deploy in the isolated test environment after the pending hold, checkout,
canonical account and blind-shift migrations. Verify existing real tokens for
profile bans/inactivation and deleted Auth identities through all three RPCs,
then repeat a successful checkout before production approval.

Save schema-only pre-deployment RPC definitions and ACLs for incident recovery.
Prefer a forward repair if a valid profile fails eligibility. Restoring the old
bodies reopens the account-state bypass and requires explicit approval with
booking mutations contained. No customer rows or prices are changed by this
migration. Pushing `dev` does not deploy it to hosted Supabase.
