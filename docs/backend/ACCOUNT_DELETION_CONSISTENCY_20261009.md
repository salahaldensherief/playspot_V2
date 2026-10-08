# Account deletion failure consistency

The deployed delete-account v6 sends five separate DELETE requests, a profile update, then an Auth ban. A late table failure leaves earlier deletions committed. An Auth failure leaves an anonymized but enabled application profile.

Migration 20261009000004 moves the existing five deletions and profile anonymization into one service-only transaction. It locks the target profile, sets is_active=false and is_banned=true, and records a pending Auth disable in account_deletion_requests. Bookings, payments and lounge ownership retain the existing policy. Profile role/ownership removal and data-retention policy are separate product questions, not silently changed here.

The dashboard repository's delete-account handler resolves the caller with Auth getUser, ignores any target in the request body, invokes this RPC with the service credential, retries Auth disabling twice, then records completion. A permanent Auth outage returns 503 with deactivated=true. A lost completion acknowledgment returns 503 with auth_disabled=true. Neither is a success response. The durable record remains pending until reconciliation; this change does not add an automatic worker.

## Validation and deployment

Native PostgreSQL fixture tests inject a failure on the final table and assert complete rollback, check user scope, preserve bookings/payments, enforce service-only access, and replay pending/completed requests. Node tests run the actual TypeScript handler with synthetic Auth/database responses. They do not verify Supabase Auth token invalidation or hosted Edge behavior.

Before deployment, test the migration with staging's actual tables, triggers and grants. Apply the migration first, verify service-only RPC and table privileges, then deploy the matching delete-account Edge function separately. Test a disposable customer only, with injected database/Auth outages and recovery. Never use production customer deletion as a smoke test. Existing JWTs may survive Auth state changes; remaining RLS/legacy RPC checks must still be audited.

Operations must monitor `SELECT user_id, requested_at FROM public.account_deletion_requests WHERE auth_disabled_at IS NULL`. With a server-side service credential, reapply Auth updateUserById(user_id,{ban_duration:'876000h'}); only after confirmed success update that user's auth_disabled_at. If the user already appears banned, verify it with Auth Admin before acknowledging. Do not grant this work to a mobile/dashboard client. Retrying the endpoint may work while the user's token remains valid; operations cannot rely on that after Auth ban/token expiration.

The reviewed rollback revokes service execution while preserving pending records and disabled profiles. Disable the Edge endpoint as the first containment step; restoring the old sequential handler reintroduces the failure. Anonymized data cannot be recovered by a schema rollback.

Source and isolated tests only: no migration or Edge production deployment was performed.
