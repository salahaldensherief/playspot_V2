-- DRAFT FOR CODEX REVIEW ONLY. Do not apply to production.
-- Proposed isolated PlaySpot Bridge metadata and message ledger.
-- Existing booking/payment/session authority is intentionally unchanged.
-- Before promotion: review existing migrations and add tested API/worker/RLS.
-- Fresh disposable databases only: deliberately fail on existing objects/schema drift.
-- The additional public.rooms unique constraint is part of this PROPOSAL only.
-- It must be reviewed for index cost/locking before an official migration.
BEGIN;

CREATE TABLE private.integration_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  display_name text NOT NULL,
  integration_kind text NOT NULL CHECK
    (integration_kind IN ('cloud_api', 'local_agent', 'hybrid', 'assisted')),
  supported_capabilities jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(supported_capabilities) = 'object'),
  approval_state text NOT NULL DEFAULT 'draft'
    CHECK (approval_state IN ('draft', 'verified', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE private.integration_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  submitted_by uuid NOT NULL REFERENCES auth.users(id),
  questionnaire_version text NOT NULL DEFAULT '1.0.0',
  answers jsonb NOT NULL CHECK (jsonb_typeof(answers) = 'object'),
  review_state text NOT NULL DEFAULT 'submitted'
    CHECK (review_state IN ('submitted', 'needs_info', 'reviewed', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id)
);

CREATE INDEX integration_assessments_lounge_created_idx
  ON private.integration_assessments (lounge_id, created_at DESC);

CREATE TABLE private.lounge_integrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  provider_id uuid NOT NULL REFERENCES private.integration_providers(id),
  channel text NOT NULL CHECK (channel IN ('cloud_api', 'local_agent', 'hybrid')),
  state text NOT NULL DEFAULT 'draft'
    CHECK (state IN ('draft', 'awaiting_review', 'pilot', 'active', 'paused', 'failed', 'revoked')),
  capabilities jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(capabilities) = 'object'),
  availability_authority text NOT NULL DEFAULT 'unverified'
    CHECK (availability_authority IN ('unverified', 'external', 'playspot', 'manual')),
  created_at timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz,
  approved_by uuid REFERENCES auth.users(id),
  verified_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (state <> 'active' OR
    (approved_at IS NOT NULL AND approved_by IS NOT NULL
     AND verified_at IS NOT NULL AND availability_authority <> 'unverified')),
  UNIQUE (id, lounge_id),
  UNIQUE (lounge_id, provider_id)
);

CREATE INDEX lounge_integrations_lounge_state_idx
  ON private.lounge_integrations (lounge_id, state);

ALTER TABLE public.rooms ADD CONSTRAINT bridge_room_tenant_identity UNIQUE (id, lounge_id);

CREATE TABLE private.integration_resource_mappings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id uuid NOT NULL,
  lounge_id uuid NOT NULL,
  room_id uuid NOT NULL,
  FOREIGN KEY (integration_id, lounge_id)
    REFERENCES private.lounge_integrations(id, lounge_id) ON UPDATE RESTRICT,
  FOREIGN KEY (room_id, lounge_id)
    REFERENCES public.rooms(id, lounge_id) ON UPDATE RESTRICT,
  external_resource_id text NOT NULL CHECK (length(trim(external_resource_id)) BETWEEN 1 AND 255),
  mapping_state text NOT NULL DEFAULT 'draft'
    CHECK (mapping_state IN ('draft', 'verified', 'disabled')),
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (integration_id, room_id),
  UNIQUE (integration_id, external_resource_id)
);

-- Composite foreign keys protect both child writes and parent tenant changes.
-- Unlike a one-sided validation trigger, they also serialize concurrent updates.

CREATE TABLE private.integration_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id uuid NOT NULL REFERENCES private.lounge_integrations(id),
  device_public_id uuid NOT NULL UNIQUE,
  last_heartbeat_at timestamptz,
  status text NOT NULL DEFAULT 'unpaired'
    CHECK (status IN ('unpaired', 'paired', 'offline', 'revoked')),
  agent_version text,
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  -- No private keys, passwords, tokens or one-time pairing secrets in this table.
  UNIQUE (integration_id, device_public_id)
);

CREATE TABLE private.integration_command_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id uuid NOT NULL REFERENCES private.lounge_integrations(id),
  idempotency_key text NOT NULL CHECK (length(trim(idempotency_key)) BETWEEN 1 AND 200),
  operation_type text NOT NULL CHECK (operation_type IN
    ('reserve', 'cancel_reservation', 'start_session', 'extend_session', 'end_session', 'refresh_availability')),
  request_payload jsonb NOT NULL CHECK (jsonb_typeof(request_payload) = 'object'),
  state text NOT NULL DEFAULT 'queued' CHECK (state IN
    ('queued','leased','acknowledged','rejected','ambiguous','requires_review','cancelled')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count BETWEEN 0 AND 50),
  next_attempt_at timestamptz,
  locked_until timestamptz,
  requested_by uuid REFERENCES auth.users(id),
  correlation_id text,
  external_receipt_id text,
  response_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (integration_id, idempotency_key)
);

CREATE INDEX integration_commands_pending_idx
 ON private.integration_command_queue (next_attempt_at, created_at)
 WHERE state = 'queued';

CREATE TABLE private.integration_inbound_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id uuid NOT NULL REFERENCES private.lounge_integrations(id),
  external_event_id text NOT NULL CHECK (length(trim(external_event_id)) BETWEEN 1 AND 255),
  event_type text NOT NULL,
  event_payload jsonb NOT NULL CHECK (jsonb_typeof(event_payload) = 'object'),
  source_timestamp timestamptz,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  result text NOT NULL DEFAULT 'pending'
    CHECK (result IN ('pending', 'applied', 'ignored', 'needs_review', 'failed')),
  UNIQUE (integration_id, external_event_id)
);

CREATE TABLE private.integration_reconciliation_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id uuid NOT NULL REFERENCES private.lounge_integrations(id),
  began_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  status text NOT NULL DEFAULT 'running'
    CHECK (status IN ('running','consistent','diverged','failed','needs_review')),
  mismatch_count integer NOT NULL DEFAULT 0 CHECK (mismatch_count >= 0),
  summary jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(summary) = 'object')
);

-- Fail closed: not in the Data API; no client privileges or RLS policies.
-- Only a separately reviewed server/worker path may access these records.
ALTER TABLE private.integration_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.integration_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.lounge_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.integration_resource_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.integration_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.integration_command_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.integration_inbound_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.integration_reconciliation_runs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON private.integration_providers FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.integration_assessments FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.lounge_integrations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.integration_resource_mappings FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.integration_agents FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.integration_command_queue FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.integration_inbound_events FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.integration_reconciliation_runs FROM PUBLIC, anon, authenticated;

COMMIT;
