# Lounge review contract

Source: 20261001110000_versioned_lounge_review.sql. Not applied live.
Tested with 20 sequential synthetic PostgreSQL checks. PostGIS, production triggers
and concurrent writers remain staging requirements.

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

Known legacy onboarding issue: initial onboard_lounge creation does not provide the
payment destination required by the current lounge constraint; draft creation must
be repaired before enabling the complete registration flow. New user registration
must preserve access to pending/rejected onboarding rather than treat pending review
as a suspended account. This migration alone does not solve that bootstrap flow.