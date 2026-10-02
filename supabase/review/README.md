# Backend SQL review candidates

The `dev` integration contains all backend source while keeping the 16 newly
introduced SQL candidates under `review/migrations/`, outside the Supabase CLI
and GitHub integration's automatic `supabase/migrations/` discovery path.
Existing migrations already present on `dev` remain in their original directory.
The candidate files were moved byte-for-byte; native fixture imports now use
their review paths. `supabase/repairs/` remains review-only too.

Do not treat this source integration as database deployment. The hosted migration
history was inspected read-only on 2026-10-02 and ends with
`20260929110324_gate_booking_loyalty_on_paid_completion`. These new candidates have
not been applied by this work. Existing Supabase main/waitlist/open-time branch
metadata reports MIGRATIONS_FAILED; no hosted branch was created, reset or merged.

Before moving any candidate back to the deployment directory, verify its actual
hosted prerequisites, schema/RLS/grants/trigger compatibility, data preservation,
lock ordering, client rollout and staging integration. Several older P0/P1/P2
drafts contain known unreviewed authorization/financial gaps documented in
docs/backend. They cannot be blindly replayed as a production release.
