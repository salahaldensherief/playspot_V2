# Occupancy and booking holds

The hosted `acquire_booking_hold` definition observed on 2026-10-09 permits future requests under the venue's existing advance-day, shift and working-hour rules. Its room predicate nevertheless requires `is_available=true`. Session start sets an occupied room's flag false, so a different future interval is rejected before capacity is checked. Current checkout pricing and the mobile room catalog already distinguish maintenance from occupancy.

Migration `20261009000001_booking_hold_occupied_room_capacity.sql` preserves that observed function and changes only room eligibility: active rooms must be available or occupied, and maintenance/deleted rooms are rejected even if an inconsistent availability flag is true. An available room with a false flag remains administratively disabled. Confirmed booking periods and other customers' live holds still reject overlaps. The existing `private.guard_cashier_online_hold` trigger remains installed and still rejects an offline writer. No writer or availability flags are changed by the migration.

The mobile card and selected-room submission also reject administrative disablement, while occupied rooms remain eligible when the requested date has capacity. These are previews; final hold and checkout authorization remain on the server.

## Validation and deployment

The regression fails against the observed hosted definition with SQLSTATE 23514 on a nonoverlapping occupied room. PostgreSQL 17.11 passes nine scenarios after the change, including maintenance, disabled/inactive rooms, confirmed overlap, competing holds, adjacent periods, the offline barrier, and two concurrent transactions contending on the actual room advisory mutex. Synthetic Auth/permission fixtures do not prove hosted RLS or a complete payment/Realtime journey.

This is source only. Pushing `dev` does not apply this migration. Before an approved database deployment:

1. Compare `pg_get_functiondef('public.acquire_booking_hold(uuid[],timestamp,timestamp,integer)'::regprocedure)` with the observed fixture `supabase/tests/fixtures/hosted_booking_hold_contract.sql`. If it changed, merge against the newer definition instead of overwriting it. Verify the writer guard trigger and current grants remain present.
2. Apply only this new migration to an isolated staging project; do not replay the historical migration chain on a hosted project. Use test users, an active shift and a genuine writer lease, then perform hold → quote → checkout → dashboard → mobile Realtime, alongside overlap and administrative-disable cases.
3. Deploy to production only after explicit production approval. Inspect errors and preserve existing room/shift/hold records.
4. If required, use the reviewed rollback `supabase/review/rollbacks/20261009000001_booking_hold_occupied_room_capacity.sql` after comparing any newer function changes. It restores the observed function predicate without deleting bookings, holds, grants or writer state. Existing occupied-room future holds may then be rejected on renewal; inspect them before rollback.

The wider future-request policy (including unconfirmed requests and no-shift operation) is unchanged. Complete checkout and hosted staging validation remain required.
