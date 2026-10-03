# Authorized live rollout, 2026-10-03

The user explicitly authorized applying reviewed repairs to the live project.
Project: `tgpdexoitemmpruepgyt`. Canonical migrations remain in this repository.

## Applied

- `20261003103608_live_security_boundaries.sql`: active/unbanned canonical platform administrator; financial table write grants and restrictive read boundaries; slot-waitlist invoker view and actor-bound insert; platform revenue actor contract; public table management grants/default grants.
- `20261003104630_live_versioned_onboarding_kyc.sql`: immutable venue review revisions; owner draft bootstrap/resource save/submission and review/rejection/re-entry RPCs. Legacy owner-wide KYC mutation RPCs retired. Existing 22 approved legacy submissions preserved; no existing venue activated. The profile-write-grants candidate was deliberately excluded until the client administrative commands are coordinated.
- `20261003110859_owner_auth_provisioning.sql`: service-only atomic and idempotent application-record provisioning, with an active canonical administrator check. Auth accounts are created through the Auth Admin API by the `create-lounge-owner` Edge Function in the Dashboard repository. Legacy authenticated SQL Auth-account creation retired. Existing accounts cannot be reassigned. Pending venues remain closed and unpublished.
- `20261003111319_promotion_delete_scope.sql`: global promotion records with NULL venue are distinguished from missing records. Only an eligible canonical administrator manages global offers; venue marketing permission remains required for other users. Create/update/delete use the same boundary, and mutation lookups lock their rows.

## Verification and limits

Catalog definitions/ACLs/RLS/policies were saved before rollout; this is a catalog snapshot, not a full data backup. Read-only live checks confirmed the new RPCs, narrow grants, retired legacy routes, preserved KYC records, invoker view, and administrator eligibility. No real bookings, collections, approvals, or owner accounts were created as production tests.

Local PostgreSQL 17.11 owner provisioning fixture: 14 checks. Promotion fixture: 11 checks. Dashboard Edge request tests: 10 checks. Dashboard HTTP boundary tests cover the actual Edge path and reject incomplete success/permission/duplicate/uncertain results without SQL fallbacks. These do not constitute a successful browser-to-live-Auth owner-creation test.

An uncertain Auth/finalization response retains the newly created account for recovery and reports an unconfirmed operation; it never deletes an account whose application transaction may already have committed. The server log records only the owner identifier. A confirmed finalization retry returns the same venue.

Remaining security/platform constraints: extension-owned `public.spatial_ref_sys` retains management privileges owned by `supabase_admin`, which the SQL migration role cannot revoke; it was not forcibly reassigned. Supabase leaked-password protection requires a paid plan; no subscription was purchased. The full offline UI wiring, administrative profile command coordination, broad widget localization sweep, and authenticated live end-to-end validation remain separate unfinished work. Do not label the whole platform production-ready based on these repairs.
