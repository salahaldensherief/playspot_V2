-- PlaySpot Verified Manual Refund and Reversal Accounting
-- Completes actual manual refund initiation, custody-aware execution, partial/full
-- reversal movements, shift cash drawer outflows, commission/payout liability
-- adjustments, and payment/booking state reconciliation.

CREATE TABLE IF NOT EXISTS private.booking_refund_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id uuid NOT NULL UNIQUE,
  booking_id uuid NOT NULL REFERENCES public.bookings(id),
  payment_id uuid NOT NULL REFERENCES public.payments(id),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  target_movement_id uuid NOT NULL REFERENCES private.booking_money_movements(id),
  requested_amount_minor bigint NOT NULL CHECK (requested_amount_minor > 0),
  approved_commission_reversal_minor bigint NOT NULL CHECK (
    approved_commission_reversal_minor >= 0
    AND approved_commission_reversal_minor <= requested_amount_minor
  ),
  funds_holder text NOT NULL CHECK (funds_holder IN ('platform', 'lounge')),
  refund_reason text NOT NULL CHECK (length(trim(refund_reason)) BETWEEN 1 AND 500),
  policy_decision jsonb NOT NULL,
  policy_override boolean NOT NULL DEFAULT false,
  status text NOT NULL CHECK (status IN ('approved_pending_return', 'completed', 'cancelled')),
  initiated_by uuid NOT NULL REFERENCES auth.users(id),
  initiated_at timestamptz NOT NULL DEFAULT now(),
  execution_operation_id uuid UNIQUE,
  refund_movement_id uuid UNIQUE REFERENCES private.booking_money_movements(id),
  shift_id uuid REFERENCES public.shifts(id),
  shift_expense_id uuid UNIQUE REFERENCES public.shift_expenses(id),
  return_payment_method text CHECK (
    return_payment_method IS NULL
    OR return_payment_method IN (
      'cash',
      'manual_transfer',
      'card',
      'vodafone_cash',
      'fawry',
      'instapay',
      'app_wallet'
    )
  ),
  evidence_reference text CHECK (
    evidence_reference IS NULL
    OR length(trim(evidence_reference)) BETWEEN 1 AND 500
  ),
  executed_by uuid REFERENCES auth.users(id),
  executed_at timestamptz,
  cancelled_by uuid REFERENCES auth.users(id),
  cancelled_at timestamptz,
  cancellation_reason text CHECK (
    cancellation_reason IS NULL
    OR length(trim(cancellation_reason)) BETWEEN 1 AND 500
  ),
  CONSTRAINT booking_refund_request_lifecycle_shape CHECK (
    (
      status = 'approved_pending_return'
      AND refund_movement_id IS NULL
      AND execution_operation_id IS NULL
      AND executed_by IS NULL
      AND executed_at IS NULL
      AND cancelled_by IS NULL
      AND cancelled_at IS NULL
    )
    OR (
      status = 'completed'
      AND refund_movement_id IS NOT NULL
      AND execution_operation_id IS NOT NULL
      AND return_payment_method IS NOT NULL
      AND evidence_reference IS NOT NULL
      AND executed_by IS NOT NULL
      AND executed_at IS NOT NULL
      AND cancelled_by IS NULL
      AND cancelled_at IS NULL
    )
    OR (
      status = 'cancelled'
      AND refund_movement_id IS NULL
      AND execution_operation_id IS NULL
      AND cancelled_by IS NOT NULL
      AND cancelled_at IS NOT NULL
      AND cancellation_reason IS NOT NULL
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_booking_refund_requests_booking_status
  ON private.booking_refund_requests(booking_id, status, initiated_at);

CREATE INDEX IF NOT EXISTS idx_booking_refund_requests_target_movement
  ON private.booking_refund_requests(target_movement_id, status);

ALTER TABLE private.booking_refund_requests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.booking_refund_requests
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.validate_booking_money_movement()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_payment public.payments%ROWTYPE;
  v_shift_payment public.shift_payments%ROWTYPE;
  v_original private.booking_money_movements%ROWTYPE;
  v_refunded_minor bigint;
  v_refunded_commission_minor bigint;
BEGIN
  SELECT * INTO v_payment FROM public.payments WHERE id = NEW.payment_id;
  IF NOT FOUND OR v_payment.booking_id IS DISTINCT FROM NEW.booking_id
    OR v_payment.lounge_id IS DISTINCT FROM NEW.lounge_id THEN
    RAISE EXCEPTION 'MOVEMENT_PAYMENT_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;
  PERFORM 1 FROM public.bookings b WHERE b.id = NEW.booking_id
    AND b.lounge_id = NEW.lounge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MOVEMENT_BOOKING_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;
  PERFORM 1 FROM public.shifts s WHERE s.id = NEW.shift_id
    AND s.lounge_id = NEW.lounge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MOVEMENT_SHIFT_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;

  IF NEW.movement_type = 'collection' THEN
    SELECT * INTO v_shift_payment FROM public.shift_payments
    WHERE id = NEW.shift_payment_id;
    IF NOT FOUND OR v_shift_payment.booking_id IS DISTINCT FROM NEW.booking_id
      OR v_shift_payment.lounge_id IS DISTINCT FROM NEW.lounge_id
      OR v_shift_payment.shift_id IS DISTINCT FROM NEW.shift_id
      OR v_shift_payment.payment_method IS DISTINCT FROM NEW.payment_method
      OR v_shift_payment.amount * 100 IS DISTINCT FROM NEW.amount_minor THEN
      RAISE EXCEPTION 'MOVEMENT_SHIFT_EVIDENCE_MISMATCH' USING ERRCODE = '23514';
    END IF;
  ELSE
    SELECT * INTO v_original FROM private.booking_money_movements
    WHERE id = NEW.reversal_of FOR UPDATE;
    IF NOT FOUND OR v_original.movement_type <> 'collection'
      OR v_original.booking_id IS DISTINCT FROM NEW.booking_id
      OR v_original.payment_id IS DISTINCT FROM NEW.payment_id
      OR v_original.lounge_id IS DISTINCT FROM NEW.lounge_id THEN
      RAISE EXCEPTION 'REFUND_COLLECTION_SCOPE_MISMATCH' USING ERRCODE = '23514';
    END IF;
    IF NEW.funds_holder IS DISTINCT FROM v_original.funds_holder THEN
      RAISE EXCEPTION 'REFUND_CUSTODY_MISMATCH' USING ERRCODE = '22023';
    END IF;
    SELECT COALESCE(-sum(amount_minor), 0), COALESCE(-sum(commission_minor), 0)
      INTO v_refunded_minor, v_refunded_commission_minor
    FROM private.booking_money_movements
    WHERE reversal_of = NEW.reversal_of;
    IF v_refunded_minor - NEW.amount_minor > v_original.amount_minor
      OR v_refunded_commission_minor - NEW.commission_minor > v_original.commission_minor THEN
      RAISE EXCEPTION 'REFUND_EXCEEDS_VERIFIED_COLLECTION' USING ERRCODE = '22023';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.validate_booking_money_movement()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.assert_booking_movement_not_payout_locked(
  p_payment_id uuid,
  p_movement_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_payment public.payments%ROWTYPE;
  v_active_payout_status text;
BEGIN
  SELECT *
  INTO v_payment
  FROM public.payments
  WHERE id = p_payment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PAYMENT_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_payment.payout_id IS NOT NULL THEN
    RAISE EXCEPTION 'PAYMENT_LOCKED_BY_PAYOUT'
      USING ERRCODE = '55000';
  END IF;

  SELECT p.status
  INTO v_active_payout_status
  FROM private.booking_movement_payout_entries e
  JOIN public.payouts p ON p.id = e.payout_id
  WHERE e.movement_id = p_movement_id
    AND p.status IN ('pending', 'approved', 'processing', 'needs_review')
  LIMIT 1;

  IF v_active_payout_status IS NOT NULL THEN
    RAISE EXCEPTION 'MOVEMENT_LOCKED_BY_ACTIVE_PAYOUT'
      USING ERRCODE = '55000';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION private.assert_booking_movement_not_payout_locked(uuid, uuid)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.calculate_refund_commission_minor(
  p_original_id uuid,
  p_refund_amount_minor bigint,
  p_exclude_request_id uuid DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_original private.booking_money_movements%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_rate numeric;
  v_executed_refunded_amount bigint;
  v_executed_refunded_commission bigint;
  v_pending_requested_amount bigint;
  v_pending_requested_commission bigint;
  v_available_amount bigint;
  v_available_commission bigint;
  v_after_amount bigint;
  v_target_remaining_commission bigint;
BEGIN
  IF p_refund_amount_minor IS NULL OR p_refund_amount_minor <= 0 THEN
    RAISE EXCEPTION 'INVALID_REFUND_AMOUNT'
      USING ERRCODE = '22023';
  END IF;

  SELECT *
  INTO v_original
  FROM private.booking_money_movements
  WHERE id = p_original_id
  FOR UPDATE;

  IF NOT FOUND OR v_original.movement_type <> 'collection' THEN
    RAISE EXCEPTION 'COLLECTION_MOVEMENT_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT *
  INTO v_payment
  FROM public.payments
  WHERE id = v_original.payment_id;

  v_rate := COALESCE(
    v_payment.commission_rate,
    CASE
      WHEN v_original.amount_minor > 0 THEN
        v_original.commission_minor::numeric / v_original.amount_minor::numeric
      ELSE private.platform_commission_rate()
    END
  );

  SELECT
    COALESCE(-sum(m.amount_minor), 0),
    COALESCE(-sum(m.commission_minor), 0)
  INTO v_executed_refunded_amount, v_executed_refunded_commission
  FROM private.booking_money_movements m
  WHERE m.reversal_of = p_original_id
    AND m.movement_type = 'refund';

  SELECT
    COALESCE(sum(r.requested_amount_minor), 0),
    COALESCE(sum(r.approved_commission_reversal_minor), 0)
  INTO v_pending_requested_amount, v_pending_requested_commission
  FROM private.booking_refund_requests r
  WHERE r.target_movement_id = p_original_id
    AND r.status = 'approved_pending_return'
    AND (p_exclude_request_id IS NULL OR r.id <> p_exclude_request_id);

  v_available_amount :=
    v_original.amount_minor - v_executed_refunded_amount - v_pending_requested_amount;
  v_available_commission :=
    v_original.commission_minor - v_executed_refunded_commission - v_pending_requested_commission;

  IF p_refund_amount_minor > v_available_amount OR v_available_amount <= 0 THEN
    RAISE EXCEPTION 'REFUND_EXCEEDS_AVAILABLE_COLLECTION'
      USING ERRCODE = '22023';
  END IF;

  IF p_refund_amount_minor = v_available_amount THEN
    RETURN GREATEST(0, LEAST(p_refund_amount_minor, v_available_commission));
  END IF;

  v_after_amount := v_available_amount - p_refund_amount_minor;
  v_target_remaining_commission := round(v_after_amount::numeric * v_rate)::bigint;

  RETURN GREATEST(
    0,
    LEAST(
      v_available_commission,
      p_refund_amount_minor,
      v_available_commission - v_target_remaining_commission
    )
  );
END;
$function$;

REVOKE ALL ON FUNCTION private.calculate_refund_commission_minor(uuid, bigint, uuid)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.enforce_payment_financials()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_rate numeric := private.platform_commission_rate();
  v_movement_count integer := 0;
  v_movement_amount_minor bigint := 0;
  v_movement_commission_minor bigint := 0;
BEGIN
  IF NEW.amount IS NULL OR NEW.amount < 0 THEN
    RAISE EXCEPTION 'Payment amount must be non-negative'
      USING ERRCODE = '22023';
  END IF;

  NEW.commission_rate := v_rate;

  IF NEW.id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM private.cash_collection_context c
    WHERE c.transaction_id = txid_current()
      AND c.booking_id = NEW.booking_id
  ) THEN
    SELECT
      count(*)::integer,
      COALESCE(sum(m.amount_minor), 0),
      COALESCE(sum(m.commission_minor), 0)
    INTO v_movement_count, v_movement_amount_minor, v_movement_commission_minor
    FROM private.booking_money_movements m
    WHERE m.payment_id = NEW.id;

    IF v_movement_count > 0
       AND round(v_movement_amount_minor::numeric / 100, 2) = round(NEW.amount, 2) THEN
      NEW.commission := round(v_movement_commission_minor::numeric / 100, 2);
      NEW.net_to_lounge := NEW.amount - NEW.commission;
      RETURN NEW;
    END IF;
  END IF;

  NEW.commission := round(NEW.amount * v_rate, 2);
  NEW.net_to_lounge := NEW.amount - NEW.commission;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE VIEW private.booking_money_coverage
WITH (security_invoker = true) AS
SELECT
  p.id AS payment_id,
  p.booking_id,
  p.lounge_id,
  (p.amount * 100)::bigint AS aggregate_gross_minor,
  COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'collection'), 0)::bigint
    AS movement_gross_minor,
  COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'refund'), 0)::bigint
    AS refunded_minor,
  count(m.id) FILTER (WHERE m.movement_type = 'collection')::integer
    AS collection_count,
  CASE
    WHEN count(m.id) = 0 THEN 'legacy_unclassified'
    WHEN COALESCE(sum(m.amount_minor), 0) IS DISTINCT FROM (p.amount * 100)::bigint
      OR p.status NOT IN ('completed', 'refunded') THEN 'requires_reconciliation'
    ELSE 'covered'
  END AS coverage_state,
  COALESCE(sum(m.amount_minor), 0)::bigint AS movement_net_minor
FROM public.payments p
LEFT JOIN private.booking_money_movements m ON m.payment_id = p.id
GROUP BY p.id, p.booking_id, p.lounge_id, p.amount, p.status;

REVOKE ALL ON private.booking_money_coverage
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.cash_collection_paid_amount(
  p_booking_id uuid,
  p_lounge_id uuid,
  p_payment_status text
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_payment public.payments%ROWTYPE;
  v_cash numeric;
  v_shift_gross numeric;
  v_movement_gross bigint;
  v_movement_net bigint;
  v_movement_count bigint;
BEGIN
  SELECT * INTO v_payment FROM public.payments
    WHERE booking_id = p_booking_id FOR UPDATE;
  SELECT
    count(*) FILTER (WHERE movement_type = 'collection'),
    COALESCE(sum(amount_minor) FILTER (WHERE movement_type = 'collection'), 0),
    COALESCE(sum(amount_minor), 0)
  INTO v_movement_count, v_movement_gross, v_movement_net
  FROM private.booking_money_movements
  WHERE booking_id = p_booking_id;

  IF v_movement_count > 0 THEN
    SELECT COALESCE(sum(amount), 0) INTO v_shift_gross
    FROM public.shift_payments
    WHERE booking_id = p_booking_id AND lounge_id = p_lounge_id
      AND category = 'gaming_time';

    IF v_payment.id IS NULL
      OR v_payment.status NOT IN ('completed', 'refunded')
      OR (v_payment.status = 'refunded' AND v_movement_net <> 0)
      OR (v_payment.status = 'completed' AND v_movement_net <= 0 AND v_movement_gross > 0)
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_payment.payout_id IS NOT NULL
      OR v_payment.amount IS NULL OR v_payment.amount < 0
      OR v_payment.amount::text IN ('NaN', 'Infinity', '-Infinity')
      OR v_payment.amount <> round(v_payment.amount, 2)
      OR (v_payment.amount * 100)::bigint IS DISTINCT FROM v_movement_net
      OR (v_shift_gross * 100)::bigint IS DISTINCT FROM v_movement_gross THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
    END IF;
    RETURN v_payment.amount;
  END IF;

  SELECT COALESCE(sum(amount), 0) INTO v_cash FROM public.shift_payments
    WHERE booking_id = p_booking_id AND lounge_id = p_lounge_id
      AND payment_method = 'cash';
  IF v_payment.id IS NOT NULL THEN
    IF v_payment.payment_method IS DISTINCT FROM 'cash'
      OR v_payment.status IS DISTINCT FROM 'completed'
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_payment.payout_id IS NOT NULL OR v_payment.amount IS NULL
      OR v_payment.amount < 0 OR v_payment.amount::text IN ('NaN', 'Infinity', '-Infinity')
      OR v_payment.amount <> round(v_payment.amount, 2)
      OR v_payment.amount IS DISTINCT FROM v_cash THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
    END IF;
    RETURN v_payment.amount;
  ELSIF p_payment_status IS DISTINCT FROM 'unpaid' OR v_cash <> 0 THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;
  RETURN 0;
END;
$function$;

REVOKE ALL ON FUNCTION private.cash_collection_paid_amount(uuid, uuid, text)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.booking_collected_amount(
  p_booking_id uuid,
  p_lounge_id uuid,
  p_legacy_status text,
  p_total numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_payment public.payments%ROWTYPE;
  v_cash numeric;
  v_shift_gross numeric;
  v_movement_count bigint;
  v_movement_gross bigint;
  v_movement_net bigint;
BEGIN
  SELECT * INTO v_payment FROM public.payments WHERE booking_id = p_booking_id FOR UPDATE;
  SELECT
    count(*) FILTER (WHERE movement_type = 'collection'),
    COALESCE(sum(amount_minor) FILTER (WHERE movement_type = 'collection'), 0),
    COALESCE(sum(amount_minor), 0)
  INTO v_movement_count, v_movement_gross, v_movement_net
  FROM private.booking_money_movements
  WHERE booking_id = p_booking_id;

  IF v_movement_count > 0 THEN
    SELECT COALESCE(sum(amount), 0) INTO v_shift_gross
    FROM public.shift_payments
    WHERE booking_id = p_booking_id AND lounge_id = p_lounge_id
      AND category = 'gaming_time';

    IF v_payment.id IS NULL
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_payment.status NOT IN ('completed', 'refunded')
      OR (v_payment.status = 'refunded' AND v_movement_net <> 0)
      OR (v_payment.status = 'completed' AND v_movement_net <= 0 AND v_movement_gross > 0)
      OR v_payment.amount IS NULL OR v_payment.amount < 0
      OR v_payment.amount <> round(v_payment.amount, 2)
      OR v_payment.amount::text IN ('NaN', 'Infinity', '-Infinity')
      OR (v_payment.amount * 100)::bigint IS DISTINCT FROM v_movement_net
      OR (v_shift_gross * 100)::bigint IS DISTINCT FROM v_movement_gross THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
    END IF;
    RETURN v_payment.amount;
  END IF;

  IF v_payment.id IS NULL THEN
    IF (p_legacy_status IS DISTINCT FROM 'unpaid' AND p_total <> 0)
      OR EXISTS(SELECT 1 FROM public.shift_payments WHERE booking_id = p_booking_id AND amount <> 0) THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
    END IF;
    RETURN 0;
  END IF;
  IF v_payment.lounge_id IS DISTINCT FROM p_lounge_id OR v_payment.status IS DISTINCT FROM 'completed'
    OR v_payment.amount IS NULL OR v_payment.amount < 0 OR v_payment.amount <> round(v_payment.amount, 2)
    OR v_payment.amount::text IN ('NaN', 'Infinity', '-Infinity') THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;
  IF v_payment.payment_method = 'cash'
    OR EXISTS(SELECT 1 FROM private.cash_collection_receipts WHERE booking_id = p_booking_id) THEN
    SELECT COALESCE(sum(amount), 0) INTO v_cash FROM public.shift_payments
      WHERE booking_id = p_booking_id AND lounge_id = p_lounge_id AND payment_method = 'cash';
    IF v_payment.payment_method IS DISTINCT FROM 'cash' OR v_payment.amount IS DISTINCT FROM v_cash THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
    END IF;
  END IF;
  RETURN v_payment.amount;
END;
$function$;

REVOKE ALL ON FUNCTION private.booking_collected_amount(uuid, uuid, text, numeric)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.apply_partial_cash_collection_with_movement(
  p_booking_id uuid,
  p_shift_id uuid,
  p_amount_minor numeric,
  p_operation_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_lounge_id uuid;
  v_allow_cash boolean;
  v_old_payment public.payments%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_has_movements boolean;
  v_has_electronic boolean;
  v_shift_payment_id uuid;
  v_movement_id uuid;
  v_rate numeric;
  v_new_commission_minor bigint;
  v_prior_commission_minor bigint;
  v_booking public.bookings%ROWTYPE;
  v_paid numeric;
  v_amount numeric;
BEGIN
  SELECT lounge_id INTO v_lounge_id FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  SELECT allow_cash_payment INTO v_allow_cash FROM public.lounges
    WHERE id = v_lounge_id;
  IF v_allow_cash IS NOT TRUE THEN
    RAISE EXCEPTION 'CASH_COLLECTION_DISABLED' USING ERRCODE = '42501';
  END IF;
  SELECT EXISTS(SELECT 1 FROM private.booking_money_movements
    WHERE booking_id = p_booking_id AND movement_type = 'collection'),
    EXISTS(SELECT 1 FROM private.booking_money_movements
    WHERE booking_id = p_booking_id AND movement_type = 'collection'
      AND payment_method <> 'cash')
    INTO v_has_movements, v_has_electronic;
  SELECT * INTO v_old_payment FROM public.payments
    WHERE booking_id = p_booking_id FOR UPDATE;
  IF v_old_payment.id IS NOT NULL AND v_has_movements IS FALSE THEN
    RETURN private.apply_partial_cash_collection(p_booking_id, p_shift_id, p_amount_minor);
  END IF;
  v_rate := private.platform_commission_rate();
  IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 1
    OR v_rate::text IN ('NaN', 'Infinity', '-Infinity')
    OR (v_has_movements AND v_old_payment.commission_rate IS DISTINCT FROM v_rate) THEN
    RAISE EXCEPTION 'MIXED_COMMISSION_POLICY_REQUIRES_RECONCILIATION'
      USING ERRCODE = '55000';
  END IF;
  v_new_commission_minor :=
    (round((p_amount_minor / 100) * v_rate, 2) * 100)::bigint;
  SELECT COALESCE(sum(commission_minor), 0) INTO v_prior_commission_minor
  FROM private.booking_money_movements
  WHERE booking_id = p_booking_id;
  v_booking := private.lock_cash_collection_booking(p_booking_id);
  PERFORM private.lock_cash_collection_shift(p_shift_id, v_booking.lounge_id);
  v_paid := private.cash_collection_paid_amount(
    p_booking_id, v_booking.lounge_id, v_booking.payment_status);
  v_amount := p_amount_minor / 100;
  IF v_amount > v_booking.total_price - v_paid THEN
    RAISE EXCEPTION 'CASH_EXCEEDS_OUTSTANDING_BALANCE' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.cash_collection_context(transaction_id, booking_id)
    VALUES(txid_current(), p_booking_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.payments(booking_id, user_id, lounge_id, amount,
    commission_rate, commission, net_to_lounge, payment_method, status, paid_at)
  VALUES(p_booking_id, v_booking.user_id, v_booking.lounge_id, v_paid + v_amount,
    v_rate, round((v_prior_commission_minor + v_new_commission_minor)::numeric / 100, 2),
    (v_paid + v_amount) - round((v_prior_commission_minor + v_new_commission_minor)::numeric / 100, 2),
    CASE WHEN v_has_electronic THEN 'mixed' ELSE 'cash' END,
    'completed', now())
  ON CONFLICT(booking_id) DO UPDATE SET amount = EXCLUDED.amount,
    commission_rate = EXCLUDED.commission_rate,
    commission = EXCLUDED.commission, net_to_lounge = EXCLUDED.net_to_lounge,
    payment_method = EXCLUDED.payment_method, status = 'completed', paid_at = EXCLUDED.paid_at;
  INSERT INTO public.shift_payments(shift_id, lounge_id, booking_id,
    payment_method, category, amount, paid_at)
  VALUES(p_shift_id, v_booking.lounge_id, p_booking_id, 'cash',
    'gaming_time', v_amount, now()) RETURNING id INTO v_shift_payment_id;
  UPDATE public.bookings SET
    payment_status = CASE WHEN v_paid + v_amount = total_price THEN 'paid'
      ELSE 'partial' END,
    payment_method = CASE WHEN v_has_electronic THEN 'mixed' ELSE 'cash' END,
    updated_at = now() WHERE id = p_booking_id;
  DELETE FROM private.cash_collection_context
    WHERE transaction_id = txid_current() AND booking_id = p_booking_id;
  SELECT * INTO STRICT v_payment FROM public.payments
    WHERE booking_id = p_booking_id;
  IF (v_payment.commission * 100)::bigint IS DISTINCT FROM
      v_prior_commission_minor + v_new_commission_minor THEN
    RAISE EXCEPTION 'MIXED_COMMISSION_ALLOCATION_CONFLICT' USING ERRCODE = '55000';
  END IF;
  INSERT INTO private.booking_money_movements(operation_id, booking_id,
    payment_id, lounge_id, shift_id, shift_payment_id, movement_type,
    collection_purpose, payment_method, amount_minor, commission_minor,
    funds_holder, verified_by)
  VALUES(p_operation_id, p_booking_id, v_payment.id, v_lounge_id, p_shift_id,
    v_shift_payment_id, 'collection', 'settlement', 'cash', p_amount_minor::bigint,
    v_new_commission_minor, 'lounge', auth.uid())
  RETURNING id INTO v_movement_id;
  RETURN jsonb_build_object('booking_id', p_booking_id, 'lounge_id',
    v_booking.lounge_id, 'shift_id', p_shift_id,
    'shift_payment_id', v_shift_payment_id, 'collected_minor', p_amount_minor,
    'paid_minor', (v_paid + v_amount) * 100,
    'due_minor', (v_booking.total_price - v_paid - v_amount) * 100,
    'payment_status', CASE WHEN v_paid + v_amount = v_booking.total_price
      THEN 'paid' ELSE 'partial' END, 'movement_id', v_movement_id);
END;
$function$;

REVOKE ALL ON FUNCTION private.apply_partial_cash_collection_with_movement(
  uuid, uuid, numeric, uuid) FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.reject_manual_booking(
  p_booking_id uuid,
  p_rejection_reason text,
  p_action_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_actor uuid := auth.uid();
  v_reason text := NULLIF(btrim(p_rejection_reason), '');
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_action_by IS NOT NULL AND p_action_by IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'Action actor does not match authenticated user'
      USING ERRCODE = '42501';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  PERFORM private.assert_lounge_operator(v_booking.lounge_id, true);

  IF COALESCE(v_booking.payment_method, '') <> 'manual_transfer' THEN
    RAISE EXCEPTION 'Only manual transfer bookings can be rejected here'
      USING ERRCODE = '55000';
  END IF;

  IF v_booking.payment_status IN ('paid', 'partial', 'refunded')
     OR COALESCE(v_booking.deposit_paid, false) IS TRUE
     OR EXISTS (
       SELECT 1
       FROM private.booking_money_movements AS m
       WHERE m.booking_id = p_booking_id
     ) THEN
    RAISE EXCEPTION 'Paid or partially paid bookings cannot be rejected through manual review'
      USING ERRCODE = '55000';
  END IF;

  IF v_booking.status NOT IN (
    'pending'::public.booking_status,
    'upcoming'::public.booking_status
  ) THEN
    RAISE EXCEPTION 'Booking cannot be rejected in its current status'
      USING ERRCODE = '55000';
  END IF;

  UPDATE public.bookings
  SET status = 'rejected'::public.booking_status,
      payment_status = 'unpaid',
      cancellation_reason = COALESCE(v_reason, 'Manual transfer was rejected'),
      cancelled_by = v_actor,
      cancelled_at = now(),
      updated_at = now()
  WHERE id = p_booking_id;

  UPDATE public.rooms AS r
  SET status = 'available',
      is_available = true,
      updated_at = now()
  WHERE r.id = v_booking.room_id
    AND r.status = 'occupied'
    AND NOT EXISTS (
      SELECT 1
      FROM public.bookings AS active_b
      WHERE active_b.room_id = r.id
        AND active_b.id <> p_booking_id
        AND active_b.status = 'in_progress'::public.booking_status
    );

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'status', 'rejected',
    'rejected_by', v_actor,
    'rejection_reason', COALESCE(v_reason, 'Manual transfer was rejected')
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.reject_manual_booking(uuid, text, uuid)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.reject_manual_booking(uuid, text, uuid)
  TO authenticated;

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

REVOKE ALL ON FUNCTION public.initiate_booking_refund(uuid, uuid, bigint, text, uuid, boolean)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.initiate_booking_refund(uuid, uuid, bigint, text, uuid, boolean)
  TO authenticated;

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

REVOKE ALL ON FUNCTION public.cancel_booking_refund_request(uuid, text)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.cancel_booking_refund_request(uuid, text)
  TO authenticated;

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

REVOKE ALL ON FUNCTION public.execute_booking_refund(uuid, text, text, uuid, uuid)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.execute_booking_refund(uuid, text, text, uuid, uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_booking_refund_summary(
  p_booking_id uuid
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
  v_gross_collected_minor bigint := 0;
  v_total_refunded_minor bigint := 0;
  v_net_collected_minor bigint := 0;
  v_gross_commission_minor bigint := 0;
  v_refunded_commission_minor bigint := 0;
  v_net_commission_minor bigint := 0;
  v_net_to_lounge_minor bigint := 0;
  v_pending_refund_minor bigint := 0;
  v_platform_payout_contribution_minor bigint := 0;
  v_lounge_payout_contribution_minor bigint := 0;
  v_movements jsonb := '[]'::jsonb;
  v_requests jsonb := '[]'::jsonb;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'BOOKING_ID_REQUIRED'
      USING ERRCODE = '22023';
  END IF;

  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    v_booking.user_id = v_actor
    OR public.is_super_admin()
    OR private.can_operate_playspot_lounge(v_booking.lounge_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized: booking refund summary access denied'
      USING ERRCODE = '42501';
  END IF;

  SELECT *
  INTO v_payment
  FROM public.payments
  WHERE booking_id = v_booking.id;

  SELECT
    COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'collection'), 0),
    COALESCE(-sum(m.amount_minor) FILTER (WHERE m.movement_type = 'refund'), 0),
    COALESCE(sum(m.amount_minor), 0),
    COALESCE(sum(m.commission_minor) FILTER (WHERE m.movement_type = 'collection'), 0),
    COALESCE(-sum(m.commission_minor) FILTER (WHERE m.movement_type = 'refund'), 0),
    COALESCE(sum(m.commission_minor), 0),
    COALESCE(sum(m.net_to_lounge_minor), 0),
    COALESCE(sum(m.net_to_lounge_minor) FILTER (WHERE m.funds_holder = 'platform'), 0),
    COALESCE(sum(-m.commission_minor) FILTER (WHERE m.funds_holder = 'lounge'), 0),
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'movement_id', m.id,
          'operation_id', m.operation_id,
          'movement_type', m.movement_type,
          'collection_purpose', m.collection_purpose,
          'payment_method', m.payment_method,
          'amount_minor', m.amount_minor,
          'commission_minor', m.commission_minor,
          'net_to_lounge_minor', m.net_to_lounge_minor,
          'funds_holder', m.funds_holder,
          'reversal_of', m.reversal_of,
          'evidence_reference', m.evidence_reference,
          'verified_at', m.verified_at
        )
        ORDER BY m.verified_at, m.id
      ),
      '[]'::jsonb
    )
  INTO
    v_gross_collected_minor,
    v_total_refunded_minor,
    v_net_collected_minor,
    v_gross_commission_minor,
    v_refunded_commission_minor,
    v_net_commission_minor,
    v_net_to_lounge_minor,
    v_platform_payout_contribution_minor,
    v_lounge_payout_contribution_minor,
    v_movements
  FROM private.booking_money_movements m
  WHERE m.booking_id = v_booking.id;

  SELECT
    COALESCE(sum(r.requested_amount_minor) FILTER (WHERE r.status = 'approved_pending_return'), 0),
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'refund_request_id', r.id,
          'operation_id', r.operation_id,
          'target_movement_id', r.target_movement_id,
          'requested_amount_minor', r.requested_amount_minor,
          'approved_commission_reversal_minor', r.approved_commission_reversal_minor,
          'funds_holder', r.funds_holder,
          'status', r.status,
          'policy_override', r.policy_override,
          'return_payment_method', r.return_payment_method,
          'refund_movement_id', r.refund_movement_id,
          'shift_expense_id', r.shift_expense_id,
          'initiated_at', r.initiated_at,
          'executed_at', r.executed_at
        )
        ORDER BY r.initiated_at, r.id
      ),
      '[]'::jsonb
    )
  INTO v_pending_refund_minor, v_requests
  FROM private.booking_refund_requests r
  WHERE r.booking_id = v_booking.id;

  RETURN jsonb_build_object(
    'booking_id', v_booking.id,
    'lounge_id', v_booking.lounge_id,
    'booking_status', v_booking.status,
    'booking_payment_status', v_booking.payment_status,
    'deposit_paid', COALESCE(v_booking.deposit_paid, false),
    'payment_id', v_payment.id,
    'payment_row_status', v_payment.status,
    'payment_row_amount_minor', CASE WHEN v_payment.id IS NULL THEN 0 ELSE round(v_payment.amount * 100)::bigint END,
    'gross_collected_minor', v_gross_collected_minor,
    'total_refunded_minor', v_total_refunded_minor,
    'net_collected_minor', v_net_collected_minor,
    'pending_refund_minor', v_pending_refund_minor,
    'refundable_remaining_minor', GREATEST(v_net_collected_minor - v_pending_refund_minor, 0),
    'gross_commission_minor', v_gross_commission_minor,
    'refunded_commission_minor', v_refunded_commission_minor,
    'net_commission_minor', v_net_commission_minor,
    'net_to_lounge_minor', v_net_to_lounge_minor,
    'platform_payout_contribution_minor', v_platform_payout_contribution_minor,
    'lounge_payout_contribution_minor', v_lounge_payout_contribution_minor,
    'total_payout_contribution_minor', v_platform_payout_contribution_minor + v_lounge_payout_contribution_minor,
    'movements', v_movements,
    'refund_requests', v_requests
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_booking_refund_summary(uuid)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_booking_refund_summary(uuid)
  TO authenticated;
