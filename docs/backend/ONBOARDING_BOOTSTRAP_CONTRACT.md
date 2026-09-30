# Onboarding bootstrap correction

20261001120000_onboarding_draft_bootstrap.sql follows the versioned review migration.
It permits pending/rejected lounge drafts without a transfer destination; active lounges
still require the existing destination invariant. No historical rows are rewritten.
The existing onboard_lounge signature and JSON response are retained. Profile locking
serializes draft creation/retries. An existing profile lounge link only permits update
when that lounge is owned by the caller. Draft setup no longer suspends the owner account.

10 isolated checks passed. Geography is stubbed in this fixture: these tests verify
identity, draft constraint behavior and replay/rollback, not PostGIS behavior. Production
triggers, geography calls, grants/RLS and concurrent owner creation require staging.
Existing inactive profiles are not blindly reactivated: suspension and old pending-account
states need explicit reconciliation. No live application has taken place.

Client dependencies remain: collect transfer details before final submission, include
stable resource IDs and use atomic/idempotent final submission, submit KYC after saving
complete lounge data, expose rejection reason and preserve drafts across retry.