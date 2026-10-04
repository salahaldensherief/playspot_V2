# Owner account access versus venue approval

## Reproduced defect

The real super-admin provisioning UI successfully called the create-owner Edge
Function, but the new profile was inactive. The owner could not enter onboarding.

Migration `20261004194130_pending_owner_onboarding_access.sql` corrects both
service-only provisioning versions: a newly created owner account is active and
not setup-complete; its venue remains pending, inactive and closed. Approval and
opening remain separate server-authorized operations. Existing idempotent
provisioning retries return before updating an account, preserving moderation.
Existing inactive accounts are not bulk-reactivated.

## Verification

- Native PostgreSQL 17.11: 21 contract checks passed, including disabled/banned
  administrator rejection, client execute denial, staff reassignment denial,
  moderated-owner replay and both versions' pending-venue behavior.
- Live function grants: anon/authenticated cannot execute either version;
  service_role can. No service key was placed in a client.
- Actual browser: super-admin created a uniquely named synthetic owner/venue;
  generated owner credentials successfully entered `/onboarding` and reached
  venue, basic-information and location steps. Database inspection confirmed
  active account, incomplete setup, pending/inactive/closed venue, zero bookings
  and zero rooms. This verifies entry, not completed KYC approval.
- The synthetic account and venue were removed using exact identifiers and
  guarded predicates after verification. No real accounts were reactivated.

Full document upload, review submission and accept/reject browser verification
remain separate from this account-access regression. Do not treat this check as
production certification for the complete onboarding flow.
