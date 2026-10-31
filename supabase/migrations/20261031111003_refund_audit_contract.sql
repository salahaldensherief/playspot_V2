-- Forward-only repair: canonical audit storage/logger, then the three refund callers.
-- Reviewed subset of 20260929130000; deliberately excludes general triggers, RPCs,
-- historic event replay and changes to unrelated financial functions.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- Never silently accept the incompatible audit table shape used by old fixtures.
DO $check$
DECLARE v_column text;
BEGIN
  IF to_regclass('public.audit_events') IS NOT NULL THEN
    FOREACH v_column IN ARRAY ARRAY['id','lounge_id','occurred_at','entity_type',
      'entity_id','booking_id','actor_user_id','severity','event_code','payload','created_at']
    LOOP
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema='public' AND table_name='audit_events' AND column_name=v_column)
      THEN RAISE EXCEPTION 'Incompatible audit_events column: %', v_column USING ERRCODE='55000'; END IF;
    END LOOP;
  END IF;
END;
$check$;

CREATE TABLE IF NOT EXISTS public.event_catalog (
  code text PRIMARY KEY, entity_type text NOT NULL,
  default_severity text NOT NULL CHECK (default_severity IN ('info','warning','critical')),
  label_key text NOT NULL, title_ar text NOT NULL, title_en text NOT NULL,
  description text, created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.event_catalog(code,entity_type,default_severity,label_key,title_ar,title_en,description)
VALUES ('payment_refunded','payment','warning','events.payment.refunded',
  'استرداد دفعة مالية','Payment Refunded','استرداد مبلغ مالي للعميل')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid REFERENCES public.lounges(id) ON DELETE CASCADE,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  entity_type text NOT NULL, entity_id text NOT NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  actor_user_id uuid,
  severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info','warning','critical')),
  event_code text NOT NULL REFERENCES public.event_catalog(code),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_events_lounge_timeline
  ON public.audit_events(lounge_id,occurred_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_booking ON public.audit_events(booking_id,occurred_at DESC)
  WHERE booking_id IS NOT NULL;
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_catalog ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.audit_events,public.event_catalog FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.audit_events,public.event_catalog TO authenticated,service_role;
DROP POLICY IF EXISTS refund_audit_read ON public.audit_events;
CREATE POLICY refund_audit_read ON public.audit_events FOR SELECT TO authenticated USING (
  public.is_super_admin()
  OR (lounge_id IS NOT NULL AND public.has_lounge_permission(lounge_id,'audit.view'))
  OR actor_user_id=(SELECT auth.uid())
  OR (booking_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.bookings b WHERE b.id=audit_events.booking_id AND b.user_id=(SELECT auth.uid())
  ))
);
DROP POLICY IF EXISTS refund_event_catalog_read ON public.event_catalog;
CREATE POLICY refund_event_catalog_read ON public.event_catalog FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION private.prevent_audit_modification()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $immutable$
BEGIN
  RAISE EXCEPTION 'Audit events are immutable and cannot be updated or deleted' USING ERRCODE='42501';
END;
$immutable$;
REVOKE ALL ON FUNCTION private.prevent_audit_modification() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS trg_audit_events_immutable ON public.audit_events;
CREATE TRIGGER trg_audit_events_immutable BEFORE UPDATE OR DELETE ON public.audit_events
FOR EACH ROW EXECUTE FUNCTION private.prevent_audit_modification();

CREATE OR REPLACE FUNCTION private.log_audit_event(
  p_lounge_id uuid,
  p_entity_type text,
  p_entity_id text,
  p_event_code text,
  p_booking_id uuid DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL,
  p_severity text DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb,
  p_occurred_at timestamptz DEFAULT now()
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_id uuid;
  v_severity text;
  v_sanitized_payload jsonb;
  v_reason text;
  v_request_id text;
BEGIN
  -- Determine default severity if omitted
  IF p_severity IS NULL THEN
    SELECT default_severity INTO v_severity
    FROM public.event_catalog
    WHERE code = p_event_code;
    v_severity := COALESCE(v_severity, 'info');
  ELSE
    v_severity := p_severity;
  END IF;

  -- Sanitize sensitive tokens and receipts
  v_sanitized_payload := COALESCE(p_payload, '{}'::jsonb) - 'fcm_token';
  IF v_sanitized_payload ? 'receipt_url' THEN
    v_sanitized_payload := (v_sanitized_payload - 'receipt_url') || jsonb_build_object('receipt_url_present', true);
  END IF;

  -- Capture contextual reason or request_id if set in transaction
  BEGIN
    v_reason := NULLIF(btrim(current_setting('app.audit_reason', true)), '');
    IF v_reason IS NOT NULL THEN
      v_sanitized_payload := v_sanitized_payload || jsonb_build_object('reason', v_reason);
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    v_request_id := NULLIF(btrim(current_setting('app.audit_request_id', true)), '');
    IF v_request_id IS NOT NULL THEN
      v_sanitized_payload := v_sanitized_payload || jsonb_build_object('request_id', v_request_id);
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  INSERT INTO public.audit_events (
    lounge_id, occurred_at, entity_type, entity_id, booking_id,
    actor_user_id, severity, event_code, payload, created_at
  ) VALUES (
    p_lounge_id, COALESCE(p_occurred_at, now()), p_entity_type, p_entity_id, p_booking_id,
    COALESCE(p_actor_user_id, auth.uid()), v_severity, p_event_code, v_sanitized_payload, now()
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$f$;

-- -----------------------------------------------------------------------------

REVOKE ALL ON FUNCTION private.log_audit_event(uuid,text,text,text,uuid,uuid,text,jsonb,timestamptz)
  FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
-- Only trusted server-owned functions may append audit events. No seven-argument shim.

CREATE OR REPLACE FUNCTION public.initiate_booking_refund(
  p_booking_id uuid,
  p_collection_movement_id uuid,
  p_refund_amount_minor bigint,
  p_reason text,
  p_operation_id uuid,
  p_policy_override boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := private.require_active_booking_actor();
  v_booking public.bookings%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_movement private.booking_money_movements%ROWTYPE;
  v_existing private.booking_refund_requests%ROWTYPE;
  v_request private.booking_refund_requests%ROWTYPE;
  v_reason text := NULLIF(btrim(p_reason), '');
  v_policy jsonb;
  v_commission_reversal_minor bigint;
BEGIN
  IF p_booking_id IS NULL OR p_collection_movement_id IS NULL OR p_operation_id IS NULL THEN
    RAISE EXCEPTION 'BOOKING_MOVEMENT_AND_OPERATION_REQUIRED'
      USING ERRCODE = '22023';
  END IF;

  IF v_reason IS NULL OR length(v_reason) > 500 THEN
    RAISE EXCEPTION 'REFUND_REASON_REQUIRED'
      USING ERRCODE = '22023';
  END IF;

  IF p_refund_amount_minor IS NULL OR p_refund_amount_minor <= 0 THEN
    RAISE EXCEPTION 'INVALID_REFUND_AMOUNT'
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_booking_id::text, 0));

  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT *
  INTO v_existing
  FROM private.booking_refund_requests
  WHERE operation_id = p_operation_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.booking_id IS DISTINCT FROM p_booking_id
       OR v_existing.target_movement_id IS DISTINCT FROM p_collection_movement_id
       OR v_existing.requested_amount_minor IS DISTINCT FROM p_refund_amount_minor
       OR v_existing.refund_reason IS DISTINCT FROM v_reason
       OR v_existing.policy_override IS DISTINCT FROM COALESCE(p_policy_override, false) THEN
      RAISE EXCEPTION 'REFUND_INITIATION_REPLAY_CONFLICT'
        USING ERRCODE = '22023';
    END IF;

    IF v_existing.funds_holder = 'platform' THEN
      PERFORM private.assert_payout_admin();
    ELSIF NOT (
      public.is_super_admin()
      OR private.can_manage_playspot_lounge(v_booking.lounge_id)
      OR public.has_lounge_permission(v_booking.lounge_id, 'bookings_cancel')
      OR public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout')
    ) THEN
      RAISE EXCEPTION 'Unauthorized: refund initiation permission required'
        USING ERRCODE = '42501';
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'replayed', true,
      'refund_request_id', v_existing.id,
      'operation_id', v_existing.operation_id,
      'booking_id', v_existing.booking_id,
      'payment_id', v_existing.payment_id,
      'collection_movement_id', v_existing.target_movement_id,
      'requested_amount_minor', v_existing.requested_amount_minor,
      'requested_amount', round(v_existing.requested_amount_minor::numeric / 100, 2),
      'approved_commission_reversal_minor', v_existing.approved_commission_reversal_minor,
      'funds_holder', v_existing.funds_holder,
      'status', v_existing.status,
      'policy_override', v_existing.policy_override,
      'policy_decision', v_existing.policy_decision
    );
  END IF;

  SELECT *
  INTO v_movement
  FROM private.booking_money_movements
  WHERE id = p_collection_movement_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_movement.booking_id IS DISTINCT FROM p_booking_id
     OR v_movement.movement_type <> 'collection' THEN
    RAISE EXCEPTION 'COLLECTION_MOVEMENT_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_movement.funds_holder = 'platform' THEN
    PERFORM private.assert_payout_admin();
  ELSE
    IF NOT (
      public.is_super_admin()
      OR private.can_manage_playspot_lounge(v_booking.lounge_id)
      OR public.has_lounge_permission(v_booking.lounge_id, 'bookings_cancel')
      OR public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout')
    ) THEN
      RAISE EXCEPTION 'Unauthorized: refund initiation permission required'
        USING ERRCODE = '42501';
    END IF;

    IF COALESCE(p_policy_override, false) IS TRUE
       AND NOT (public.is_super_admin() OR private.can_manage_playspot_lounge(v_booking.lounge_id)) THEN
      RAISE EXCEPTION 'Unauthorized: policy override requires lounge manager or owner'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT *
  INTO v_payment
  FROM public.payments
  WHERE id = v_movement.payment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PAYMENT_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  PERFORM private.assert_booking_movement_not_payout_locked(v_payment.id, v_movement.id);

  v_policy := private.booking_refund_policy_decision(p_booking_id);
  IF v_movement.collection_purpose = 'deposit'
     AND COALESCE(p_policy_override, false) IS FALSE
     AND (
       (v_policy->>'decision') IN ('cutoff_passed', 'session_started')
       OR (
         (v_policy ? 'eligible_percentage')
         AND p_refund_amount_minor > round(
           v_movement.amount_minor::numeric
           * COALESCE((v_policy->>'eligible_percentage')::numeric, 0) / 100.0
         )::bigint
       )
     ) THEN
    RAISE EXCEPTION 'DEPOSIT_NOT_REFUNDABLE_UNDER_BRANCH_POLICY'
      USING ERRCODE = '55000';
  END IF;

  v_commission_reversal_minor := private.calculate_refund_commission_minor(
    v_movement.id,
    p_refund_amount_minor,
    NULL
  );

  INSERT INTO private.booking_refund_requests(
    operation_id,
    booking_id,
    payment_id,
    lounge_id,
    target_movement_id,
    requested_amount_minor,
    approved_commission_reversal_minor,
    funds_holder,
    refund_reason,
    policy_decision,
    policy_override,
    status,
    initiated_by,
    initiated_at
  )
  VALUES (
    p_operation_id,
    v_booking.id,
    v_payment.id,
    v_booking.lounge_id,
    v_movement.id,
    p_refund_amount_minor,
    v_commission_reversal_minor,
    v_movement.funds_holder,
    v_reason,
    v_policy,
    COALESCE(p_policy_override, false),
    'approved_pending_return',
    v_actor,
    now()
  )
  RETURNING *
  INTO v_request;

  PERFORM private.log_audit_event(
    v_booking.lounge_id,
    'payment',
    v_request.id::text,
    'payment_refunded',
    v_booking.id,
    v_actor,
    'info',
    jsonb_build_object(
      'stage', 'initiated',
      'refund_request_id', v_request.id,
      'collection_movement_id', v_movement.id,
      'requested_amount_minor', v_request.requested_amount_minor,
      'approved_commission_reversal_minor', v_request.approved_commission_reversal_minor,
      'funds_holder', v_request.funds_holder,
      'policy_override', v_request.policy_override,
      'reason', v_request.refund_reason
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'replayed', false,
    'refund_request_id', v_request.id,
    'operation_id', v_request.operation_id,
    'booking_id', v_request.booking_id,
    'payment_id', v_request.payment_id,
    'collection_movement_id', v_request.target_movement_id,
    'requested_amount_minor', v_request.requested_amount_minor,
    'requested_amount', round(v_request.requested_amount_minor::numeric / 100, 2),
    'approved_commission_reversal_minor', v_request.approved_commission_reversal_minor,
    'funds_holder', v_request.funds_holder,
    'status', v_request.status,
    'policy_override', v_request.policy_override,
    'policy_decision', v_request.policy_decision
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_booking_refund_request(
  p_refund_request_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := private.require_active_booking_actor();
  v_request private.booking_refund_requests%ROWTYPE;
  v_reason text := NULLIF(btrim(p_reason), '');
BEGIN
  IF p_refund_request_id IS NULL OR v_reason IS NULL OR length(v_reason) > 500 THEN
    RAISE EXCEPTION 'REFUND_REQUEST_AND_REASON_REQUIRED'
      USING ERRCODE = '22023';
  END IF;

  SELECT *
  INTO v_request
  FROM private.booking_refund_requests
  WHERE id = p_refund_request_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REFUND_REQUEST_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_request.booking_id::text, 0));

  -- Acquire the booking lock before any refund request row lock.
  SELECT * INTO v_request FROM private.booking_refund_requests
  WHERE id = p_refund_request_id FOR UPDATE;

  IF v_request.funds_holder = 'platform' THEN
    PERFORM private.assert_payout_admin();
  ELSIF NOT (
    public.is_super_admin()
    OR private.can_manage_playspot_lounge(v_request.lounge_id)
    OR public.has_lounge_permission(v_request.lounge_id, 'bookings_cancel')
    OR public.has_lounge_permission(v_request.lounge_id, 'billing_checkout')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: refund cancellation permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_request.status = 'cancelled' THEN
    RETURN jsonb_build_object(
      'success', true,
      'replayed', true,
      'refund_request_id', v_request.id,
      'booking_id', v_request.booking_id,
      'status', v_request.status,
      'cancellation_reason', v_request.cancellation_reason
    );
  END IF;

  IF v_request.status <> 'approved_pending_return' THEN
    RAISE EXCEPTION 'COMPLETED_REFUND_CANNOT_BE_CANCELLED'
      USING ERRCODE = '55000';
  END IF;

  UPDATE private.booking_refund_requests
  SET status = 'cancelled',
      cancelled_by = v_actor,
      cancelled_at = now(),
      cancellation_reason = v_reason
  WHERE id = v_request.id
  RETURNING *
  INTO v_request;

  PERFORM private.log_audit_event(
    v_request.lounge_id,
    'payment',
    v_request.id::text,
    'payment_refunded',
    v_request.booking_id,
    v_actor,
    'info',
    jsonb_build_object(
      'stage', 'cancelled',
      'refund_request_id', v_request.id,
      'reason', v_reason
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'replayed', false,
    'refund_request_id', v_request.id,
    'booking_id', v_request.booking_id,
    'status', v_request.status,
    'cancellation_reason', v_request.cancellation_reason
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.execute_booking_refund(
  p_refund_request_id uuid,
  p_return_payment_method text,
  p_evidence_reference text,
  p_operation_id uuid,
  p_shift_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := private.require_active_booking_actor();
  v_request private.booking_refund_requests%ROWTYPE;
  v_existing_movement private.booking_money_movements%ROWTYPE;
  v_original private.booking_money_movements%ROWTYPE;
  v_refund_movement private.booking_money_movements%ROWTYPE;
  v_booking public.bookings%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_shift public.shifts%ROWTYPE;
  v_evidence text := NULLIF(btrim(p_evidence_reference), '');
  v_method text := NULLIF(btrim(p_return_payment_method), '');
  v_shift_id uuid;
  v_shift_expense_id uuid;
  v_shift_cash_sales numeric := 0;
  v_shift_expenses numeric := 0;
  v_available_drawer_minor bigint := 0;
  v_commission_reversal_minor bigint;
  v_net_collected_minor bigint := 0;
  v_gross_collected_minor bigint := 0;
  v_total_refunded_minor bigint := 0;
  v_net_deposit_minor bigint := 0;
  v_booking_total_minor bigint := 0;
  v_net_amount numeric := 0;
  v_payment_row_status text;
  v_booking_payment_status text;
  v_deposit_paid boolean;
BEGIN
  IF p_refund_request_id IS NULL OR p_operation_id IS NULL THEN
    RAISE EXCEPTION 'REFUND_REQUEST_AND_OPERATION_REQUIRED'
      USING ERRCODE = '22023';
  END IF;

  IF v_evidence IS NULL OR length(v_evidence) > 500 THEN
    RAISE EXCEPTION 'EVIDENCE_REFERENCE_REQUIRED'
      USING ERRCODE = '22023';
  END IF;

  IF v_method IS NULL OR v_method NOT IN (
    'cash',
    'manual_transfer',
    'card',
    'vodafone_cash',
    'fawry',
    'instapay',
    'app_wallet'
  ) THEN
    RAISE EXCEPTION 'INVALID_RETURN_PAYMENT_METHOD'
      USING ERRCODE = '22023';
  END IF;

  SELECT *
  INTO v_request
  FROM private.booking_refund_requests
  WHERE id = p_refund_request_id;

  IF FOUND THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_request.booking_id::text, 0));
  END IF;

  SELECT *
  INTO v_existing_movement
  FROM private.booking_money_movements m
  WHERE m.operation_id = p_operation_id;

  IF FOUND THEN
    SELECT *
    INTO v_request
    FROM private.booking_refund_requests r
    WHERE r.execution_operation_id = p_operation_id
       OR r.refund_movement_id = v_existing_movement.id;

    IF NOT FOUND
       OR v_existing_movement.movement_type <> 'refund'
       OR v_request.id IS DISTINCT FROM p_refund_request_id
       OR v_request.return_payment_method IS DISTINCT FROM v_method
       OR v_request.evidence_reference IS DISTINCT FROM v_evidence
       OR (p_shift_id IS NOT NULL AND v_request.shift_id IS DISTINCT FROM p_shift_id) THEN
      RAISE EXCEPTION 'REFUND_EXECUTION_REPLAY_CONFLICT'
        USING ERRCODE = '22023';
    END IF;

    IF v_request.funds_holder = 'platform' THEN
      PERFORM private.assert_payout_admin();
    ELSIF NOT (
      public.is_super_admin()
      OR private.can_manage_playspot_lounge(v_request.lounge_id)
      OR public.has_lounge_permission(v_request.lounge_id, 'billing_checkout')
    ) THEN
      RAISE EXCEPTION 'Unauthorized: billing_checkout permission required'
        USING ERRCODE = '42501';
    END IF;

    SELECT *
    INTO v_booking
    FROM public.bookings
    WHERE id = v_request.booking_id;

    SELECT *
    INTO v_payment
    FROM public.payments
    WHERE id = v_request.payment_id;

    SELECT
      COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'collection'), 0),
      COALESCE(-sum(m.amount_minor) FILTER (WHERE m.movement_type = 'refund'), 0),
      COALESCE(sum(m.amount_minor), 0)
    INTO v_gross_collected_minor, v_total_refunded_minor, v_net_collected_minor
    FROM private.booking_money_movements m
    WHERE m.booking_id = v_request.booking_id;

    RETURN jsonb_build_object(
      'success', true,
      'replayed', true,
      'refund_request_id', v_request.id,
      'refund_movement_id', v_existing_movement.id,
      'operation_id', p_operation_id,
      'booking_id', v_request.booking_id,
      'payment_id', v_request.payment_id,
      'reversal_of', v_existing_movement.reversal_of,
      'refunded_amount_minor', -v_existing_movement.amount_minor,
      'refunded_amount', round((-v_existing_movement.amount_minor)::numeric / 100, 2),
      'commission_reversed_minor', -v_existing_movement.commission_minor,
      'net_to_lounge_reversed_minor', -v_existing_movement.net_to_lounge_minor,
      'funds_holder', v_existing_movement.funds_holder,
      'return_payment_method', v_existing_movement.payment_method,
      'shift_id', v_request.shift_id,
      'shift_expense_id', v_request.shift_expense_id,
      'gross_collected_minor', v_gross_collected_minor,
      'total_refunded_minor', v_total_refunded_minor,
      'net_collected_minor', v_net_collected_minor,
      'payment_status', v_booking.payment_status,
      'payment_row_status', v_payment.status
    );
  END IF;

  SELECT *
  INTO v_request
  FROM private.booking_refund_requests
  WHERE id = p_refund_request_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REFUND_REQUEST_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_request.booking_id::text, 0));

  SELECT *
  INTO v_request
  FROM private.booking_refund_requests
  WHERE id = p_refund_request_id
  FOR UPDATE;

  IF v_request.status <> 'approved_pending_return' THEN
    RAISE EXCEPTION 'REFUND_REQUEST_NOT_PENDING'
      USING ERRCODE = '55000';
  END IF;

  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = v_request.booking_id
  FOR UPDATE;

  SELECT *
  INTO v_payment
  FROM public.payments
  WHERE id = v_request.payment_id
  FOR UPDATE;

  SELECT *
  INTO v_original
  FROM private.booking_money_movements
  WHERE id = v_request.target_movement_id
  FOR UPDATE;

  IF NOT FOUND OR v_original.movement_type <> 'collection' THEN
    RAISE EXCEPTION 'COLLECTION_MOVEMENT_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  PERFORM private.assert_booking_movement_not_payout_locked(v_payment.id, v_original.id);

  IF v_original.funds_holder = 'platform' THEN
    PERFORM private.assert_payout_admin();

    IF v_method = 'cash' THEN
      RAISE EXCEPTION 'PLATFORM_REFUND_CANNOT_USE_CASH'
        USING ERRCODE = '22023';
    END IF;

    IF p_shift_id IS NOT NULL THEN
      SELECT *
      INTO v_shift
      FROM public.shifts
      WHERE id = p_shift_id;

      IF NOT FOUND OR v_shift.lounge_id IS DISTINCT FROM v_booking.lounge_id THEN
        RAISE EXCEPTION 'SHIFT_LOUNGE_MISMATCH'
          USING ERRCODE = '22023';
      END IF;
      v_shift_id := p_shift_id;
    ELSE
      v_shift_id := v_original.shift_id;
    END IF;
  ELSE
    IF NOT (
      public.is_super_admin()
      OR private.can_manage_playspot_lounge(v_booking.lounge_id)
      OR public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout')
    ) THEN
      RAISE EXCEPTION 'Unauthorized: billing_checkout permission required'
        USING ERRCODE = '42501';
    END IF;

    IF v_method = 'cash' THEN
      IF p_shift_id IS NULL THEN
        RAISE EXCEPTION 'OPEN_SHIFT_REQUIRED_FOR_CASH_REFUND'
          USING ERRCODE = '55000';
      END IF;

      PERFORM private.lock_cash_collection_shift(p_shift_id, v_booking.lounge_id);

      SELECT *
      INTO v_shift
      FROM public.shifts
      WHERE id = p_shift_id
      FOR UPDATE;

      v_shift_id := v_shift.id;

      SELECT COALESCE(round(sum(sp.amount), 2), 0)
      INTO v_shift_cash_sales
      FROM public.shift_payments sp
      WHERE sp.shift_id = v_shift_id
        AND sp.payment_method = 'cash';

      SELECT COALESCE(round(sum(se.amount), 2), 0)
      INTO v_shift_expenses
      FROM public.shift_expenses se
      WHERE se.shift_id = v_shift_id
        AND COALESCE(se.expense_type, 'expense') IN ('cash_drop', 'expense', 'other');

      v_available_drawer_minor :=
        round((COALESCE(v_shift.starting_cash, 0) + v_shift_cash_sales - v_shift_expenses) * 100)::bigint;

      IF v_available_drawer_minor < v_request.requested_amount_minor THEN
        RAISE EXCEPTION 'SHIFT_INSUFFICIENT_CASH_FOR_REFUND'
          USING ERRCODE = '22023';
      END IF;

      INSERT INTO public.shift_expenses(
        shift_id,
        lounge_id,
        amount,
        reason,
        expense_type,
        type,
        created_by
      )
      VALUES (
        v_shift_id,
        v_booking.lounge_id,
        round(v_request.requested_amount_minor::numeric / 100, 2),
        'Booking refund ' || v_booking.id::text || ': ' || v_evidence,
        'other',
        'booking_refund',
        v_actor
      )
      RETURNING id
      INTO v_shift_expense_id;
    ELSE
      IF p_shift_id IS NOT NULL THEN
        SELECT *
        INTO v_shift
        FROM public.shifts
        WHERE id = p_shift_id;

        IF NOT FOUND OR v_shift.lounge_id IS DISTINCT FROM v_booking.lounge_id THEN
          RAISE EXCEPTION 'SHIFT_LOUNGE_MISMATCH'
            USING ERRCODE = '22023';
        END IF;
        v_shift_id := p_shift_id;
      ELSE
        v_shift_id := v_original.shift_id;
      END IF;
    END IF;
  END IF;

  v_commission_reversal_minor := private.calculate_refund_commission_minor(
    v_original.id,
    v_request.requested_amount_minor,
    v_request.id
  );

  INSERT INTO private.cash_collection_context(transaction_id, booking_id)
  VALUES (txid_current(), v_booking.id)
  ON CONFLICT DO NOTHING;

  INSERT INTO private.booking_money_movements(
    operation_id,
    booking_id,
    payment_id,
    lounge_id,
    shift_id,
    shift_payment_id,
    movement_type,
    collection_purpose,
    payment_method,
    amount_minor,
    commission_minor,
    funds_holder,
    evidence_reference,
    reversal_of,
    verified_by,
    verified_at
  )
  VALUES (
    p_operation_id,
    v_booking.id,
    v_payment.id,
    v_booking.lounge_id,
    v_shift_id,
    NULL,
    'refund',
    'refund',
    v_method,
    -v_request.requested_amount_minor,
    -v_commission_reversal_minor,
    v_original.funds_holder,
    v_evidence,
    v_original.id,
    v_actor,
    now()
  )
  RETURNING *
  INTO v_refund_movement;

  SELECT
    COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'collection'), 0),
    COALESCE(-sum(m.amount_minor) FILTER (WHERE m.movement_type = 'refund'), 0),
    COALESCE(sum(m.amount_minor), 0)
  INTO v_gross_collected_minor, v_total_refunded_minor, v_net_collected_minor
  FROM private.booking_money_movements m
  WHERE m.booking_id = v_booking.id;

  IF v_net_collected_minor < 0 THEN
    RAISE EXCEPTION 'NEGATIVE_NET_BOOKING_COLLECTION'
      USING ERRCODE = '22023';
  END IF;

  v_net_amount := round(v_net_collected_minor::numeric / 100, 2);
  v_payment_row_status := CASE WHEN v_net_collected_minor = 0 THEN 'refunded' ELSE 'completed' END;

  UPDATE public.payments
  SET amount = v_net_amount,
      discount_amount = CASE
        WHEN discount_amount IS NULL THEN NULL
        ELSE LEAST(discount_amount, v_net_amount)
      END,
      status = v_payment_row_status
  WHERE id = v_payment.id
  RETURNING *
  INTO v_payment;

  DELETE FROM private.cash_collection_context
  WHERE transaction_id = txid_current()
    AND booking_id = v_booking.id;

  SELECT COALESCE(sum(m.amount_minor), 0)
  INTO v_net_deposit_minor
  FROM private.booking_money_movements m
  WHERE m.booking_id = v_booking.id
    AND (
      (m.movement_type = 'collection' AND m.collection_purpose = 'deposit')
      OR (
        m.movement_type = 'refund'
        AND EXISTS (
          SELECT 1
          FROM private.booking_money_movements orig
          WHERE orig.id = m.reversal_of
            AND orig.collection_purpose = 'deposit'
        )
      )
    );

  v_booking_total_minor := round(COALESCE(v_booking.total_price, 0) * 100)::bigint;
  v_booking_payment_status := CASE
    WHEN v_net_collected_minor = 0 THEN 'refunded'
    WHEN v_net_collected_minor < v_booking_total_minor THEN 'partial'
    ELSE 'paid'
  END;

  v_deposit_paid := CASE
    WHEN v_net_collected_minor = 0 THEN false
    WHEN COALESCE(v_booking.deposit_required, false) THEN (v_net_deposit_minor > 0)
    ELSE COALESCE(v_booking.deposit_paid, false)
  END;

  UPDATE public.bookings
  SET payment_status = v_booking_payment_status,
      deposit_paid = v_deposit_paid,
      updated_at = now()
  WHERE id = v_booking.id
  RETURNING *
  INTO v_booking;

  UPDATE private.booking_refund_requests
  SET status = 'completed',
      execution_operation_id = p_operation_id,
      refund_movement_id = v_refund_movement.id,
      shift_id = v_shift_id,
      shift_expense_id = v_shift_expense_id,
      return_payment_method = v_method,
      evidence_reference = v_evidence,
      approved_commission_reversal_minor = v_commission_reversal_minor,
      executed_by = v_actor,
      executed_at = now()
  WHERE id = v_request.id
  RETURNING *
  INTO v_request;

  PERFORM private.log_audit_event(
    v_booking.lounge_id,
    'payment',
    v_payment.id::text,
    'payment_refunded',
    v_booking.id,
    v_actor,
    'info',
    jsonb_build_object(
      'stage', 'completed',
      'refund_request_id', v_request.id,
      'refund_movement_id', v_refund_movement.id,
      'reversal_of', v_original.id,
      'refunded_amount_minor', -v_refund_movement.amount_minor,
      'commission_reversed_minor', -v_refund_movement.commission_minor,
      'net_to_lounge_reversed_minor', -v_refund_movement.net_to_lounge_minor,
      'funds_holder', v_refund_movement.funds_holder,
      'return_payment_method', v_refund_movement.payment_method,
      'evidence_reference', v_evidence,
      'shift_id', v_shift_id,
      'shift_expense_id', v_shift_expense_id,
      'gross_collected_minor', v_gross_collected_minor,
      'total_refunded_minor', v_total_refunded_minor,
      'net_collected_minor', v_net_collected_minor,
      'booking_payment_status', v_booking.payment_status,
      'payment_row_status', v_payment.status
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'replayed', false,
    'refund_request_id', v_request.id,
    'refund_movement_id', v_refund_movement.id,
    'operation_id', p_operation_id,
    'booking_id', v_booking.id,
    'payment_id', v_payment.id,
    'reversal_of', v_original.id,
    'refunded_amount_minor', -v_refund_movement.amount_minor,
    'refunded_amount', round((-v_refund_movement.amount_minor)::numeric / 100, 2),
    'commission_reversed_minor', -v_refund_movement.commission_minor,
    'net_to_lounge_reversed_minor', -v_refund_movement.net_to_lounge_minor,
    'funds_holder', v_refund_movement.funds_holder,
    'return_payment_method', v_refund_movement.payment_method,
    'shift_id', v_shift_id,
    'shift_expense_id', v_shift_expense_id,
    'gross_collected_minor', v_gross_collected_minor,
    'total_refunded_minor', v_total_refunded_minor,
    'net_collected_minor', v_net_collected_minor,
    'payment_status', v_booking.payment_status,
    'payment_row_status', v_payment.status
  );
END;
$function$;

COMMIT;
