# Atomic staff provisioning and recovery

`20261011060637_atomic_staff_provisioning.sql` is new, un-deployed source.
Apply it to isolated staging before deploying Dashboard's `create-lounge-staff`.
Do not replay the historical migration chain against the hosted database.

Auth creation and database writes belong to different transactions. The Edge
handler first authenticates the actor and checks current canonical authority and
scoped `staff_manage`. Auth creation records trusted `app_metadata` identifying
the actor, venue and role. The service-only finalizer rechecks actor eligibility
and permissions, locks the Auth account, validates this provenance and atomically
writes the profile, membership and receipt. A failure rolls all three back.
Exact replay returns the original success without another membership; changed
identity/details and existing unrelated accounts fail closed.

If finalization is unconfirmed, the Auth account is retained and the response
contains `recovery_user_id`; deleting it could destroy an already committed staff
account. Dashboard stores the recovery reference and original non-password
fields in platform secure storage scoped to backend and actor. Retry uses the
same account. If the Auth response itself is lost, a subsequent create or duplicate
email response invokes the service-only recovery lookup. It returns an account
only when email and trusted actor/venue/role provenance match; finalization still
checks current authorization. Unrelated accounts are never adopted. Passwords
are not stored by the recovery client and must be re-entered after a restart.

The historical migration `20261005032358_cashier_conflict_review_retry.sql` is
the exact statement already present in the hosted migration ledger. Its addition
reconciles missing Git history; it is not a new production deployment candidate.
The obsolete Dashboard SQL 81 was removed because it described unsafe behavior
superseded by this deployed contract.

Verification: 12 native PostgreSQL 17.11 synthetic fixture cases, 18 Edge handler
cases and 8 focused Dashboard client/permission cases passed. These prove the
tested contracts, not integration with real Supabase Auth, hosted triggers or
device secure storage. Staging must verify real Auth creation, rollback/retry,
lost-response recovery, retained-JWT suspension, manager/cashier/owner scope,
two simultaneous attempts and correct grants before production deployment.
