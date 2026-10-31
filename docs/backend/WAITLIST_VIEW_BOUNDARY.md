# Slot waitlist boundary review — 2026-10-03

Hosted inspection was read-only. `public.slot_waitlist` has no
`security_invoker` option and is SELECT-accessible to authenticated users.
Its base table has actor-scoped RLS, which the view owner's privileges bypass.
The legacy INSTEAD OF INSERT function is SECURITY DEFINER and trusts supplied
`NEW.user_id`. No real customer rows were read through this view or modified.

`supabase/repairs/slot_waitlist_view_boundary.sql` is a review-only repair,
outside automatic migration discovery. The corresponding P1 review candidate
uses the same function body and security_invoker view option. It preserves the
legacy projection and 60-minute default, executes INSERT with caller privileges,
binds requests to auth.uid(), checks active/unbanned profile, room/venue pairing,
and initial waiting/active status. Anonymous access and direct view mutation
beyond SELECT/INSERT are revoked. Existing base-table RLS remains authoritative.
Existing base SELECT policies, including their inactive-actor behavior, are not
changed by this repair.

The fixture reproduces the old view leak on synthetic records, then tests own
and staff reads, actor binding, timing, impersonation, room mismatch, forged
notification status, inactive/banned actor, anonymous access and UPDATE denial.
All 13 checks pass locally on PGlite. Native PostgreSQL CI runs the full suite;
PGlite is not evidence of concurrent writer/lease behavior. An attempt to run
all suites on PGlite encountered existing native-only fixture assumptions
(role bootstrap and writer timing); the full verification uses native CI.

Deployment remains separate: PostgreSQL 15+, existing compatible columns,
view/trigger dependencies, caller SELECT grants on profiles/rooms and INSERT on
booking_waitlist, existing RLS, exact role grants and booking triggers must be
verified in staging. Test canonical waitlist RPC concurrency and notifications,
with real roles, before deployment. Do not grant broader table permissions to
make a compatibility fallback succeed.

Other hosted findings still block production: client TRUNCATE grants on several
application tables; active/banned identity gaps in is_super_admin; missing KYC
RPC; and disabled leaked-password protection. Existing separate repair sources
are review candidates, not deployed protections. Spatial_ref_sys is an extension
table and must not be treated like an application table or altered blindly.

Supabase references:
- [Security invoker views](https://supabase.com/docs/guides/database/postgres/row-level-security#views)
- [Security definer view advisor](https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view)
