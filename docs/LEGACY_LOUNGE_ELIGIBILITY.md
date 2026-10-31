# Legacy lounge eligibility boundary

Migration `20261010120058_eligible_legacy_lounge_access.sql` keeps the two legacy helper signatures and ACLs. `_playspot_is_super_admin` delegates to canonical `is_super_admin`; `_playspot_has_lounge_access` requires an existing Auth identity and explicitly active/unbanned profile before owner/staff/profile lounge scope. Active legitimate owners, staff, scoped cashier and platform administrator retain access; another lounge remains denied.

Observed deployed definitions ignored banned status, and owner access did not check profile eligibility. Regression fixture loads the observed hosted definitions first: banned owner access fails the assertion before migration and passes after migration. Eleven native PostgreSQL checks include a real RLS SELECT predicate, not only helper booleans. These are synthetic SQL identities, not real Supabase Auth tokens.

Deployment order: canonical active-super-admin boundary must already be installed; apply pending prior booking/mode/points/account/checkout migrations first, then this helper change. Verify definitions, ACLs, and existing-token behavior in isolated Supabase before any production proposal. This change does not fix broad shift INSERT/UPDATE grants or blind finance disclosure by itself.

Rollback: preserve the current definitions and ACLs from test environment before applying. If legitimate actors are unexpectedly denied, pause rollout and correct the eligibility/scope data or policy rather than relaxing banned access. Any approved rollback must restore the saved exact function definitions and grants; do not drop tables, delete records, or force writer release.
