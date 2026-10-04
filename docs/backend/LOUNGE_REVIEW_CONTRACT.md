# Lounge review contract

Originally authored as 20261001110000_versioned_lounge_review.sql. Its rollout,
final submission and draft re-entry contracts were deployed together in the recorded
20261003104630_live_versioned_onboarding_kyc migration. Do not replay the original
review drafts against the hosted database.

Rechecked on 2026-10-04: 30 isolated PGlite/PostgreSQL 18.3 lifecycle checks passed.
The fixture substitutes geography and does not mirror every production trigger or
concurrent writer; actual browser approval/rejection remains a separate integration check.

submit_lounge_review(p_lounge_id uuid, p_id_document_path text,
p_business_document_path text default null) -> jsonb:
success, request_id, revision, status, idempotent.
Authenticated owner only; complete address/contact/hours/map and active resource required.
Documents must already exist in private kyc-documents under caller UUID; arbitrary URLs
are rejected. A pending request cannot change under the reviewer. Same data/path retry
returns its original ID. Rejected lounge may resubmit with the next revision.

get_lounge_review_requests() -> jsonb array. Server-verified super admin only.
Includes request ID/revision/lounge/owner, full frozen lounge/resource/extra snapshot
and object paths. Frontend generates short-lived signed document URLs, never public ones.

review_lounge_request(p_request_id uuid,p_revision integer,p_approve boolean,
p_notes text default null) -> jsonb. Super admin only. Rejection requires notes.
Decision affects exactly that lounge. Approval does not open online availability.
Current owner profile is reactivated only if its selected lounge matches. A durable
notification is recorded once; equal decision retries return idempotent true.

Rollout dependency: wire onboarding final submission AFTER lounge/room/extra saves,
then upload documents and submit exact lounge ID. Existing document-only submission
and user-wide review RPCs are not equivalent. Do not deploy this additive migration
as a complete KYC release: retire old review route after the versioned client is wired,
reconcile historical requests explicitly, verify Storage bucket is private, and verify
all existing lounge/resource writers and shift triggers against review freeze locks.

The legacy payment-destination bootstrap defect was corrected in the same live
rollout: pending/rejected drafts may omit it, while final submission/activation keeps
the destination invariant. The isolated bootstrap and atomic resource-save suites
were rechecked on 2026-10-04: 10 and 13 checks passed respectively. New user registration
must preserve access to pending/rejected onboarding rather than treat pending review
as a suspended account. This migration alone does not solve that bootstrap flow.