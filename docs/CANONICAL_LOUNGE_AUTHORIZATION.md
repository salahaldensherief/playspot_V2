# Canonical lounge authorization boundary

The hosted membership helpers allowed an owner or staff member with a banned
profile to remain a lounge member. The role helper ignored bans entirely.
Operating, management and permission-role helpers also accepted nullable
eligibility flags and a retained profile after its Auth identity was deleted.
Existing access tokens can outlive those changes.

Migration `20261010131519_eligible_canonical_lounge_authorization.sql` requires an
existing `auth.users` identity, `profiles.is_active IS TRUE`, and
`profiles.is_banned IS FALSE` in all six helpers. Membership and role scopes are
preserved. Platform authority uses the existing canonical registry as well as
the supported platform role; `current_user_role()` still returns the actual
profile role. `CREATE OR REPLACE` preserves the existing function ACLs.

## Validation

`supabase/tests/canonical_lounge_authorization.test.mjs` loads the observed
schema-only definitions and reproduces the banned-owner leak when
`PLAYSPOT_CANONICAL_ACCESS_BASELINE=1`. With the migration applied it verifies
12 cases: banned/inactive/deleted/unknown accounts, nullable eligibility,
RLS denial, denial before a privileged write, cashier tenant isolation,
ownership, staff management, platform registry and absent JWT actor.
These are synthetic PostgreSQL tests, not real Auth-token or UI E2E evidence.

## Test deployment and production preparation

Apply after the pending cashier/hold/checkout and account/shift migrations,
including `20261010123112_blind_shift_read_boundary.sql`. Deploy first to the
isolated environment. Verify function definitions, preserved ACLs and real
existing-token denials through RLS/RPC before production approval. Do not
normalize nullable eligibility flags automatically: inspect whether a profile
is eligible rather than turning it active as a test workaround.

Rollback preparation: save all six pre-deployment definitions and their ACLs
using schema metadata, with no customer-row export. If a legitimate flow fails,
keep the strict eligibility checks and repair its scope in a forward migration.
Restoring the previous bodies reopens the documented suspension/deletion leak;
use that only under explicit incident authorization with affected RPC/table
access contained. This change alters no persisted rows or client payloads.

Source delivery to `dev` does not deploy this migration to Supabase.
