# Active administrator account boundary

`supabase/repairs/active_super_admin_boundary.sql` is reviewed release source,
not a migration applied to any hosted database. The existing live helper ignores
account suspension and bans. The replacement requires an existing Auth identity,
an active, explicitly unbanned profile, and either a canonical administrator role
or trusted platform membership. User-editable metadata does not grant permission.

The definer lookup keeps an empty search path and qualifies every relation.
Its narrow boolean result avoids recursion when profile RLS itself calls the helper.
Anonymous RLS callers remain compatible and always receive false for a missing uid.
Membership tables are not granted to client roles. Promote the source through the
normal coordinated migration review; no production SQL is executed by this test.

Fourteen cases passed on synthetic local PostgreSQL 17.11, covering canonical and
legacy roles, membership, disabled/banned/null eligibility, removed Auth identity,
missing profile, anonymous calls, profile policy recursion and membership access.
This does not prove full production RLS coverage, session revocation or MFA policy.
Other RPCs using ad hoc role checks still require separate review.
