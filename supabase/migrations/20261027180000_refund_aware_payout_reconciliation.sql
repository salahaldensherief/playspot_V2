-- PlaySpot Refund-Aware Payout Reconciliation
-- Connects canonical booking money movements (collections and refunds) to the
-- payout settlement lifecycle:
-- 1. Settles movement-backed collections and pre-payout refunds accurately,
--    including mixed platform/lounge custody on the same booking.
-- 2. Allows post-payout partial and full refunds after a payout is 'paid'
--    without destructively altering historical paid payouts.
-- 3. Carries unsettled post-payout refund liabilities/credits into subsequent
--    payouts via private.booking_movement_payout_entries so no movement is
--    ever settled twice and multi-period balances reconcile to the piastre.

CREATE OR REPLACE FUNCTION public.verify_booking_deposit_transfer(
  p_booking_id uuid,
  p_shift_id uuid,
  p_operation_id uuid,
  p_evidence_reference text,
  p_funds_holder text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_shift public.shifts%ROWTYPE;
  v_existing private.booking_money_movements%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_shift_payment uuid;
  v_amount numeric;
  v_amount_minor bigint;
  v_rate numeric;
  v_commission numeric;
  v_commission_minor bigint;
  v_method text;
  v_result jsonb;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_booking_id IS NULL OR p_shift_id IS NULL OR p_operation_id IS NULL
    OR p_funds_holder NOT IN ('platform', 'lounge')
    OR p_funds_holder IS NULL OR p_evidence_reference IS NULL
    OR length(trim(p_evidence_reference)) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'INVALID_DEPOSIT_VERIFICATION_REQUEST' USING ERRCODE = '22023';
  END IF;

  IF p_funds_holder = 'platform' THEN
    IF public.is_super_admin() IS NOT TRUE THEN
      RAISE EXCEPTION 'PLATFORM_DEPOSIT_REQUIRES_PLATFORM_VERIFICATION'
        USING ERRCODE = '42501';
    END IF;
    PERFORM private.assert_payout_admin();
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_booking_id::text, 0)
  );
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  IF p_funds_holder = 'lounge' THEN
    PERFORM private.assert_cash_collector(v_actor, v_booking.lounge_id);
  END IF;

  SELECT * INTO v_existing FROM private.booking_money_movements
    WHERE operation_id = p_operation_id;
  IF FOUND THEN
    IF v_existing.booking_id IS DISTINCT FROM p_booking_id
      OR v_existing.shift_id IS DISTINCT FROM p_shift_id
      OR v_existing.verified_by IS DISTINCT FROM v_actor
      OR v_existing.collection_purpose IS DISTINCT FROM 'deposit'
      OR v_existing.evidence_reference IS DISTINCT FROM trim(p_evidence_reference)
      OR v_existing.funds_holder IS DISTINCT FROM p_funds_holder THEN
      RAISE EXCEPTION 'DEPOSIT_VERIFICATION_REPLAY_CONFLICT' USING ERRCODE = '22023';
    END IF;
    RETURN jsonb_build_object(
      'operation_id', p_operation_id,
      'movement_id', v_existing.id,
      'booking_id', p_booking_id,
      'shift_id', p_shift_id,
      'payment_method', v_existing.payment_method,
      'collected_minor', v_existing.amount_minor,
      'commission_minor', v_existing.commission_minor,
      'replayed', true
    );
  END IF;

  IF p_funds_holder = 'lounge' THEN
    PERFORM private.lock_cash_collection_shift(p_shift_id, v_booking.lounge_id);
  ELSE
    SELECT * INTO v_shift FROM public.shifts WHERE id = p_shift_id FOR SHARE;
    IF NOT FOUND OR v_shift.lounge_id IS DISTINCT FROM v_booking.lounge_id THEN
      RAISE EXCEPTION 'SHIFT_LOUNGE_MISMATCH' USING ERRCODE = '22023';
    END IF;
  END IF;

  v_method := v_booking.payment_method;
  IF v_booking.confirmation_status IS DISTINCT FROM 'confirmed'
    OR v_booking.status::text NOT IN ('pending', 'upcoming')
    OR v_booking.deposit_required IS NOT TRUE
    OR v_booking.deposit_paid IS TRUE
    OR v_method IS NULL
    OR v_method NOT IN ('manual_transfer', 'instapay', 'vodafone_cash', 'app_wallet')
    OR NULLIF(trim(COALESCE(v_booking.receipt_url, '')), '') IS NULL THEN
    RAISE EXCEPTION 'BOOKING_NOT_READY_FOR_VERIFIED_DEPOSIT' USING ERRCODE = '55000';
  END IF;
  v_amount := v_booking.deposit_amount;
  IF v_booking.total_price IS NULL
    OR v_booking.total_price::text IN ('NaN', 'Infinity', '-Infinity')
    OR v_amount IS NULL OR v_amount::text IN ('NaN', 'Infinity', '-Infinity')
    OR v_amount <= 0 OR v_amount >= v_booking.total_price
    OR v_amount <> round(v_amount, 2) THEN
    RAISE EXCEPTION 'INVALID_SERVER_DEPOSIT_AMOUNT' USING ERRCODE = '22023';
  END IF;
  v_amount_minor := (v_amount * 100)::bigint;
  IF EXISTS (SELECT 1 FROM public.shift_payments WHERE booking_id = p_booking_id)
    OR EXISTS (SELECT 1 FROM private.booking_money_movements WHERE booking_id = p_booking_id) THEN
    RAISE EXCEPTION 'DEPOSIT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;
  SELECT * INTO v_payment FROM public.payments
    WHERE booking_id = p_booking_id FOR UPDATE;
  IF FOUND AND (
    v_payment.status = 'completed'
    OR v_payment.payout_id IS NOT NULL
    OR v_payment.lounge_id IS DISTINCT FROM v_booking.lounge_id
  ) THEN
    RAISE EXCEPTION 'DEPOSIT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;
  v_rate := private.platform_commission_rate();
  IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 1
    OR v_rate::text IN ('NaN', 'Infinity', '-Infinity') THEN
    RAISE EXCEPTION 'INVALID_COMMISSION_POLICY' USING ERRCODE = '55000';
  END IF;
  v_commission := round(v_amount * v_rate, 2);
  v_commission_minor := (v_commission * 100)::bigint;
  INSERT INTO private.cash_collection_context(transaction_id, booking_id)
    VALUES (txid_current(), p_booking_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.payments(
    booking_id, user_id, lounge_id, amount,
    commission_rate, commission, net_to_lounge, payment_method, status, paid_at
  )
  VALUES (
    p_booking_id, v_booking.user_id, v_booking.lounge_id, v_amount,
    v_rate, v_commission, v_amount - v_commission, v_method, 'completed', now()
  )
  ON CONFLICT (booking_id) DO UPDATE SET
    amount = EXCLUDED.amount,
    commission_rate = EXCLUDED.commission_rate,
    commission = EXCLUDED.commission,
    net_to_lounge = EXCLUDED.net_to_lounge,
    payment_method = EXCLUDED.payment_method,
    status = EXCLUDED.status,
    paid_at = EXCLUDED.paid_at
  RETURNING * INTO v_payment;
  INSERT INTO public.shift_payments(
    shift_id, lounge_id, booking_id,
    payment_method, category, amount, paid_at
  )
  VALUES (
    p_shift_id, v_booking.lounge_id, p_booking_id, v_method,
    'gaming_time', v_amount, now()
  ) RETURNING id INTO v_shift_payment;
  INSERT INTO private.booking_money_movements(
    operation_id, booking_id,
    payment_id, lounge_id, shift_id, shift_payment_id, movement_type,
    collection_purpose, payment_method, amount_minor, commission_minor,
    funds_holder, evidence_reference, verified_by
  )
  VALUES (
    p_operation_id, p_booking_id, v_payment.id, v_booking.lounge_id,
    p_shift_id, v_shift_payment, 'collection', 'deposit', v_method,
    v_amount_minor, v_commission_minor, p_funds_holder,
    trim(p_evidence_reference), v_actor
  )
  RETURNING * INTO v_existing;
  UPDATE public.bookings
  SET deposit_paid = true,
      payment_status = 'partial',
      updated_at = now()
  WHERE id = p_booking_id;
  DELETE FROM private.cash_collection_context
    WHERE transaction_id = txid_current() AND booking_id = p_booking_id;
  v_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'movement_id', v_existing.id,
    'booking_id', p_booking_id,
    'shift_id', p_shift_id,
    'payment_method', v_method,
    'collected_minor', v_amount_minor,
    'commission_minor', v_commission_minor,
    'replayed', false
  );
  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.verify_booking_deposit_transfer(uuid, uuid, uuid, text, text)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.verify_booking_deposit_transfer(uuid, uuid, uuid, text, text)
  TO authenticated;

-- Changing only the payout settlement link (payout_id) on public.payments must
-- not be blocked by guard_canonical_booking_payment_write (matching
-- guard_partial_cash_payment). All financial/status mutations still require the
-- canonical booking collection/refund writer context.
CREATE OR REPLACE FUNCTION private.guard_canonical_booking_payment_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_booking_id uuid;
  v_booking public.bookings%ROWTYPE;
BEGIN
  IF TG_OP = 'UPDATE' AND (to_jsonb(NEW) - 'payout_id') = (to_jsonb(OLD) - 'payout_id') THEN
    RETURN NEW;
  END IF;

  v_booking_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.booking_id ELSE NEW.booking_id END;
  SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking_id;
  IF FOUND AND (
    EXISTS (
      SELECT 1
      FROM private.booking_money_movements
      WHERE booking_id = v_booking_id
    )
    OR (
      v_booking.deposit_required IS TRUE
      AND v_booking.deposit_paid IS NOT TRUE
      AND v_booking.status::text IN ('pending', 'upcoming')
    )
  ) AND NOT EXISTS (
    SELECT 1
    FROM private.cash_collection_context
    WHERE transaction_id = txid_current()
      AND booking_id = v_booking_id
  ) THEN
    RAISE EXCEPTION 'CANONICAL_BOOKING_PAYMENT_WRITER_REQUIRED'
      USING ERRCODE = '55000';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$function$;

REVOKE ALL ON FUNCTION private.guard_canonical_booking_payment_write()
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
  v_payout_status text;
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

  -- Block refunds while a payout referencing this payment is in an unpaid
  -- in-flight state, or if the payment was settled in a legacy payout that has
  -- no movement-level entries. Once a movement-backed payout is 'paid', its
  -- historical snapshot is immutable and subsequent refunds are recorded as new
  -- reversal movements for future payout reconciliation.
  IF v_payment.payout_id IS NOT NULL THEN
    SELECT p.status
    INTO v_payout_status
    FROM public.payouts p
    WHERE p.id = v_payment.payout_id;

    IF v_payout_status IN ('pending', 'approved', 'processing', 'needs_review')
       OR NOT EXISTS (
         SELECT 1
         FROM private.booking_movement_payout_entries e
         WHERE e.payout_id = v_payment.payout_id
       ) THEN
      RAISE EXCEPTION 'PAYMENT_LOCKED_BY_PAYOUT'
        USING ERRCODE = '55000';
    END IF;
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

-- Also allow cash_collection_paid_amount to read movement-backed payments that
-- were previously settled in a 'paid' payout (where payout_id is non-null).
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
  v_in_flight_payout boolean := false;
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

    IF v_payment.payout_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1
        FROM public.payouts po
        WHERE po.id = v_payment.payout_id
          AND po.status IN ('pending', 'approved', 'processing', 'needs_review')
      ) INTO v_in_flight_payout;
    END IF;

    IF v_payment.id IS NULL
      OR v_payment.status NOT IN ('completed', 'refunded')
      OR (v_payment.status = 'refunded' AND v_movement_net <> 0)
      OR (v_payment.status = 'completed' AND v_movement_net <= 0 AND v_movement_gross > 0)
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_in_flight_payout IS TRUE
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

-- Helper view for movement settlement dates and unsettled status.
CREATE OR REPLACE VIEW private.movement_settlement_values AS
SELECT
  m.id AS movement_id,
  m.operation_id,
  m.booking_id,
  m.payment_id,
  m.lounge_id,
  m.shift_id,
  m.shift_payment_id,
  m.movement_type,
  m.collection_purpose,
  m.payment_method,
  m.amount_minor,
  m.commission_minor,
  m.net_to_lounge_minor,
  m.funds_holder,
  m.reversal_of,
  m.verified_by,
  m.verified_at,
  CASE
    WHEN m.funds_holder = 'platform' THEN m.net_to_lounge_minor
    ELSE -m.commission_minor
  END AS contribution_minor,
  (m.verified_at AT TIME ZONE 'Africa/Cairo')::date AS settlement_date,
  EXISTS (
    SELECT 1
    FROM private.booking_movement_payout_entries bmpe
    JOIN public.payouts po ON po.id = bmpe.payout_id
    WHERE bmpe.movement_id = m.id
      AND po.status IN ('pending', 'approved', 'processing', 'paid', 'needs_review')
  )
  OR EXISTS (
    SELECT 1
    FROM private.payout_settlement_entries pse
    JOIN public.payouts po ON po.id = pse.payout_id
    WHERE pse.payment_id = m.payment_id
      AND po.status IN ('pending', 'approved', 'processing', 'paid', 'needs_review')
      AND NOT EXISTS (
        SELECT 1
        FROM private.booking_movement_payout_entries bmpe2
        WHERE bmpe2.payout_id = po.id
      )
  ) AS is_settled,
  (
    b.id IS NULL
    OR (
      b.status::text IN ('completed', 'cancelled', 'rejected', 'expired')
      AND NOT (
        b.status::text = 'completed'
        AND b.payment_status IS DISTINCT FROM 'paid'
        AND b.payment_status IS DISTINCT FROM 'refunded'
        AND NOT EXISTS (
          SELECT 1
          FROM private.booking_money_movements r
          WHERE r.booking_id = b.id
            AND r.movement_type = 'refund'
        )
      )
    )
  ) AS booking_finalized
FROM private.booking_money_movements m
JOIN public.payments p ON p.id = m.payment_id
LEFT JOIN public.bookings b ON b.id = m.booking_id;

REVOKE ALL ON private.movement_settlement_values
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.assert_lounge_movements_reconciled(
  p_lounge_id uuid,
  p_period_end date DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  -- 1. Reject if any movement-backed payment with unsettled movements has a
  --    pending (approved_pending_return) refund request.
  IF EXISTS (
    SELECT 1
    FROM private.booking_refund_requests req
    WHERE req.lounge_id = p_lounge_id
      AND req.status = 'approved_pending_return'
      AND (
        p_period_end IS NULL
        OR (req.initiated_at AT TIME ZONE 'Africa/Cairo')::date <= p_period_end
      )
  ) THEN
    RAISE EXCEPTION 'PENDING_REFUND_REQUEST_REQUIRES_RESOLUTION'
      USING ERRCODE = '55000';
  END IF;

  -- 2. Reject if any payment with unsettled movements fails movement-to-payment
  --    amount, commission, or status reconciliation.
  IF EXISTS (
    SELECT 1
    FROM public.payments p
    JOIN (
      SELECT
        m.payment_id,
        count(*)::integer AS movement_count,
        COALESCE(sum(m.amount_minor), 0)::bigint AS net_amount_minor,
        COALESCE(sum(m.commission_minor), 0)::bigint AS net_commission_minor,
        COALESCE(sum(m.net_to_lounge_minor), 0)::bigint AS net_lounge_minor,
        bool_or(NOT m.is_settled) AS has_unsettled
      FROM private.movement_settlement_values m
      WHERE m.lounge_id = p_lounge_id
        AND (p_period_end IS NULL OR m.settlement_date <= p_period_end)
      GROUP BY m.payment_id
    ) ms ON ms.payment_id = p.id
    WHERE ms.has_unsettled IS TRUE
      AND (
        p.status NOT IN ('completed', 'refunded')
        OR p.amount IS NULL OR p.amount < 0
        OR p.amount::text IN ('NaN', 'Infinity', '-Infinity')
        OR p.amount <> round(p.amount, 2)
        OR p.commission IS NULL OR p.commission < 0 OR p.commission > p.amount
        OR p.commission::text IN ('NaN', 'Infinity', '-Infinity')
        OR p.net_to_lounge IS DISTINCT FROM (p.amount - p.commission)
        OR round(p.amount * 100)::bigint IS DISTINCT FROM (
          SELECT COALESCE(sum(all_m.amount_minor), 0)::bigint
          FROM private.booking_money_movements all_m
          WHERE all_m.payment_id = p.id
        )
        OR round(p.commission * 100)::bigint IS DISTINCT FROM (
          SELECT COALESCE(sum(all_m.commission_minor), 0)::bigint
          FROM private.booking_money_movements all_m
          WHERE all_m.payment_id = p.id
        )
      )
  ) THEN
    RAISE EXCEPTION 'PAYMENT_FINANCIALS_REQUIRE_RECONCILIATION'
      USING ERRCODE = '55000';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION private.assert_lounge_movements_reconciled(uuid, date)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION private.assert_payout_settlement(p_payout_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_payout public.payouts%ROWTYPE;
  v_total numeric;
  v_count bigint;
  v_movement_entry_count bigint;
BEGIN
  PERFORM private.assert_payout_admin();
  SELECT * INTO v_payout FROM public.payouts WHERE id = p_payout_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PAYOUT_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  PERFORM 1 FROM public.payments WHERE payout_id = p_payout_id ORDER BY id FOR UPDATE;

  SELECT count(*), COALESCE(sum(contribution), 0)
  INTO v_count, v_total
  FROM private.payout_settlement_entries
  WHERE payout_id = p_payout_id;

  IF v_count = 0 OR v_total <= 0 OR v_total IS DISTINCT FROM v_payout.total_amount THEN
    RAISE EXCEPTION 'PAYOUT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;

  SELECT count(*)
  INTO v_movement_entry_count
  FROM private.booking_movement_payout_entries
  WHERE payout_id = p_payout_id;

  -- 1. Validate legacy un-movemented settlement entries
  IF EXISTS (
    SELECT 1
    FROM private.payout_settlement_entries e
    LEFT JOIN private.payment_settlement_values p ON p.id = e.payment_id
    WHERE e.payout_id = p_payout_id
      AND NOT EXISTS (
        SELECT 1
        FROM private.booking_movement_payout_entries bmpe
        JOIN private.booking_money_movements m ON m.id = bmpe.movement_id
        WHERE bmpe.payout_id = p_payout_id
          AND m.payment_id = e.payment_id
      )
      AND (
        p.id IS NULL
        OR p.payout_id IS DISTINCT FROM p_payout_id
        OR p.status IS DISTINCT FROM 'completed'
        OR p.lounge_id IS DISTINCT FROM v_payout.lounge_id
        OR p.funds_holder IS DISTINCT FROM e.funds_holder
        OR p.payment_method IS DISTINCT FROM e.payment_method
        OR p.amount IS DISTINCT FROM e.amount
        OR p.commission IS DISTINCT FROM e.commission
        OR p.net_to_lounge IS DISTINCT FROM e.net_to_lounge
      )
  ) THEN
    RAISE EXCEPTION 'PAYOUT_PAYMENT_EVIDENCE_CHANGED' USING ERRCODE = '55000';
  END IF;

  -- 2. Validate movement-backed settlement entries
  IF v_movement_entry_count > 0 THEN
    IF EXISTS (
      SELECT 1
      FROM private.payout_settlement_entries e
      JOIN public.payments p ON p.id = e.payment_id
      JOIN (
        SELECT
          m.payment_id,
          COALESCE(sum(m.amount_minor), 0)::bigint AS amount_minor,
          COALESCE(sum(m.commission_minor), 0)::bigint AS commission_minor,
          COALESCE(sum(m.net_to_lounge_minor), 0)::bigint AS net_minor,
          COALESCE(sum(bmpe.contribution_minor), 0)::bigint AS contrib_minor
        FROM private.booking_movement_payout_entries bmpe
        JOIN private.booking_money_movements m ON m.id = bmpe.movement_id
        WHERE bmpe.payout_id = p_payout_id
        GROUP BY m.payment_id
      ) me ON me.payment_id = e.payment_id
      WHERE e.payout_id = p_payout_id
        AND (
          p.lounge_id IS DISTINCT FROM v_payout.lounge_id
          OR p.status NOT IN ('completed', 'refunded')
          OR round(e.amount * 100)::bigint IS DISTINCT FROM me.amount_minor
          OR round(e.commission * 100)::bigint IS DISTINCT FROM me.commission_minor
          OR round(e.net_to_lounge * 100)::bigint IS DISTINCT FROM me.net_minor
          OR round(e.contribution * 100)::bigint IS DISTINCT FROM me.contrib_minor
          OR round(p.amount * 100)::bigint IS DISTINCT FROM (
            SELECT COALESCE(sum(all_m.amount_minor), 0)::bigint
            FROM private.booking_money_movements all_m
            WHERE all_m.payment_id = p.id
          )
          OR round(p.commission * 100)::bigint IS DISTINCT FROM (
            SELECT COALESCE(sum(all_m.commission_minor), 0)::bigint
            FROM private.booking_money_movements all_m
            WHERE all_m.payment_id = p.id
          )
          OR (
            v_payout.status IN ('pending', 'approved', 'processing', 'needs_review')
            AND (
              p.payout_id IS DISTINCT FROM p_payout_id
              OR EXISTS (
                SELECT 1
                FROM private.booking_refund_requests req
                WHERE req.payment_id = p.id
                  AND req.status = 'approved_pending_return'
              )
              OR EXISTS (
                SELECT 1
                FROM private.booking_money_movements m_unsettled
                WHERE m_unsettled.payment_id = p.id
                  AND (
                    v_payout.period_end IS NULL
                    OR (m_unsettled.verified_at AT TIME ZONE 'Africa/Cairo')::date <= v_payout.period_end
                    OR EXISTS (
                      SELECT 1
                      FROM private.booking_movement_payout_entries bmpe_orig
                      WHERE bmpe_orig.payout_id = p_payout_id
                        AND bmpe_orig.movement_id = m_unsettled.reversal_of
                    )
                  )
                  AND NOT EXISTS (
                    SELECT 1
                    FROM private.booking_movement_payout_entries bmpe2
                    JOIN public.payouts po2 ON po2.id = bmpe2.payout_id
                    WHERE bmpe2.movement_id = m_unsettled.id
                      AND po2.status IN ('pending', 'approved', 'processing', 'paid', 'needs_review')
                  )
              )
            )
          )
        )
    ) THEN
      RAISE EXCEPTION 'PAYOUT_PAYMENT_EVIDENCE_CHANGED' USING ERRCODE = '55000';
    END IF;
  END IF;

  IF v_payout.status IN ('pending', 'approved', 'processing', 'needs_review')
     AND v_count <> (SELECT count(*) FROM public.payments WHERE payout_id = p_payout_id) THEN
    RAISE EXCEPTION 'PAYOUT_PAYMENT_EVIDENCE_CHANGED' USING ERRCODE = '55000';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION private.assert_payout_settlement(uuid)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.get_pending_payouts_overview()
RETURNS TABLE(lounge_id uuid, lounge_name text, pending_amount numeric, total_transactions bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.assert_payout_admin();

  RETURN QUERY
  WITH legacy_candidates AS (
    SELECT
      p.lounge_id,
      p.id AS item_id,
      p.financials_valid,
      p.funds_holder IS NOT NULL AS custody_known,
      CASE
        WHEN p.funds_holder = 'platform' THEN p.net_to_lounge
        WHEN p.funds_holder = 'lounge' THEN -p.commission
        ELSE 0
      END AS contribution
    FROM private.payment_settlement_values p
    WHERE p.status = 'completed'
      AND p.payout_id IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM private.booking_money_movements m
        WHERE m.payment_id = p.id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM private.cash_collection_receipts r
        JOIN public.bookings b ON b.id = r.booking_id
        WHERE r.booking_id = p.booking_id
          AND (b.status::text <> 'completed' OR b.payment_status IS DISTINCT FROM 'paid')
      )
  ),
  movement_payment_validity AS (
    SELECT
      p.lounge_id,
      bool_and(
        p.status IN ('completed', 'refunded')
        AND p.amount IS NOT NULL AND p.amount >= 0
        AND p.amount = round(p.amount, 2)
        AND p.commission IS NOT NULL AND p.commission >= 0 AND p.commission <= p.amount
        AND p.net_to_lounge = p.amount - p.commission
        AND round(p.amount * 100)::bigint = (
          SELECT COALESCE(sum(m2.amount_minor), 0)::bigint
          FROM private.booking_money_movements m2
          WHERE m2.payment_id = p.id
        )
        AND round(p.commission * 100)::bigint = (
          SELECT COALESCE(sum(m2.commission_minor), 0)::bigint
          FROM private.booking_money_movements m2
          WHERE m2.payment_id = p.id
        )
        AND NOT EXISTS (
          SELECT 1
          FROM private.booking_refund_requests req
          WHERE req.payment_id = p.id
            AND req.status = 'approved_pending_return'
        )
      ) AS all_movement_payments_valid
    FROM public.payments p
    WHERE EXISTS (
      SELECT 1
      FROM private.movement_settlement_values m
      WHERE m.payment_id = p.id
        AND NOT m.is_settled
    )
    GROUP BY p.lounge_id
  ),
  movement_candidates AS (
    SELECT
      m.lounge_id,
      m.payment_id AS item_id,
      true AS financials_valid,
      true AS custody_known,
      round(sum(m.contribution_minor)::numeric / 100, 2) AS contribution
    FROM private.movement_settlement_values m
    WHERE NOT m.is_settled
      AND m.booking_finalized IS TRUE
    GROUP BY m.lounge_id, m.payment_id
    HAVING count(*) > 0
  ),
  combined AS (
    SELECT * FROM legacy_candidates
    UNION ALL
    SELECT * FROM movement_candidates
  )
  SELECT
    c.lounge_id,
    COALESCE(l.name_ar, l.name_en, l.name)::text AS lounge_name,
    sum(c.contribution) AS pending_amount,
    count(DISTINCT c.item_id) AS total_transactions
  FROM combined c
  JOIN public.lounges l ON l.id = c.lounge_id
  LEFT JOIN movement_payment_validity mpv ON mpv.lounge_id = c.lounge_id
  GROUP BY c.lounge_id, COALESCE(l.name_ar, l.name_en, l.name), mpv.all_movement_payments_valid
  HAVING bool_and(c.financials_valid)
     AND bool_and(c.custody_known)
     AND COALESCE(mpv.all_movement_payments_valid, true) IS TRUE
     AND sum(c.contribution) > 0;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_pending_payouts_overview()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_pending_payouts_overview()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.create_payout(
  p_lounge_id uuid,
  p_period_start date,
  p_period_end date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_payout uuid;
  v_candidate_payment_ids uuid[] := ARRAY[]::uuid[];
  v_legacy_ids uuid[] := ARRAY[]::uuid[];
  v_movement_ids uuid[] := ARRAY[]::uuid[];
  v_movement_payment_ids uuid[] := ARRAY[]::uuid[];
  v_all_payment_ids uuid[] := ARRAY[]::uuid[];
  v_legacy_total numeric := 0;
  v_movement_total_minor bigint := 0;
  v_total numeric := 0;
  v_count bigint := 0;
  v_movement_count bigint := 0;
BEGIN
  PERFORM private.assert_payout_admin();
  IF p_lounge_id IS NULL OR p_period_start IS NULL OR p_period_end IS NULL OR p_period_start > p_period_end THEN
    RAISE EXCEPTION 'INVALID_PAYOUT_PERIOD' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_lounge_id::text, 0));

  IF EXISTS (
    SELECT 1
    FROM public.payouts
    WHERE lounge_id = p_lounge_id
      AND status IN ('pending', 'approved', 'processing', 'paid', 'needs_review')
      AND daterange(period_start, period_end, '[]') && daterange(p_period_start, p_period_end, '[]')
  ) THEN
    RAISE EXCEPTION 'OVERLAPPING_ACTIVE_PAYOUT' USING ERRCODE = '55000';
  END IF;

  -- Preserve canonical lock ordering: bookings -> payments -> movements,
  -- scoped strictly to candidate bookings/payments/movements that have
  -- unsettled legacy payments, unsettled canonical movements, or active
  -- pending refund requests (leaving historical paid settlements unlocked).
  PERFORM 1
  FROM public.bookings b
  WHERE b.lounge_id = p_lounge_id
    AND EXISTS (
      SELECT 1
      FROM public.payments p
      WHERE p.booking_id = b.id
        AND p.lounge_id = p_lounge_id
        AND (
          p.payout_id IS NULL
          OR EXISTS (
            SELECT 1
            FROM private.movement_settlement_values m
            WHERE m.payment_id = p.id
              AND NOT m.is_settled
          )
          OR EXISTS (
            SELECT 1
            FROM private.booking_refund_requests req
            WHERE req.payment_id = p.id
              AND req.status = 'approved_pending_return'
          )
        )
    )
  ORDER BY b.id
  FOR UPDATE;

  SELECT COALESCE(array_agg(locked_p.id ORDER BY locked_p.id), ARRAY[]::uuid[])
  INTO v_candidate_payment_ids
  FROM (
    SELECT p.id
    FROM public.payments p
    WHERE p.lounge_id = p_lounge_id
      AND (
        p.payout_id IS NULL
        OR EXISTS (
          SELECT 1
          FROM private.movement_settlement_values m
          WHERE m.payment_id = p.id
            AND NOT m.is_settled
        )
        OR EXISTS (
          SELECT 1
          FROM private.booking_refund_requests req
          WHERE req.payment_id = p.id
            AND req.status = 'approved_pending_return'
        )
      )
    ORDER BY p.id
    FOR UPDATE
  ) locked_p;

  PERFORM 1
  FROM private.booking_money_movements m
  WHERE m.lounge_id = p_lounge_id
    AND m.payment_id = ANY(v_candidate_payment_ids)
  ORDER BY m.id
  FOR UPDATE;

  -- 1. Validate legacy un-movemented payments in period
  IF EXISTS (
    SELECT 1
    FROM private.payment_settlement_values p
    WHERE p.lounge_id = p_lounge_id
      AND p.id = ANY(v_candidate_payment_ids)
      AND p.status = 'completed'
      AND p.payout_id IS NULL
      AND p.settlement_date <= p_period_end
      AND NOT EXISTS (
        SELECT 1
        FROM private.booking_money_movements m
        WHERE m.payment_id = p.id
      )
      AND p.financials_valid IS NOT TRUE
  ) THEN
    RAISE EXCEPTION 'PAYMENT_FINANCIALS_REQUIRE_RECONCILIATION' USING ERRCODE = '55000';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM private.payment_settlement_values p
    WHERE p.lounge_id = p_lounge_id
      AND p.id = ANY(v_candidate_payment_ids)
      AND p.status = 'completed'
      AND p.payout_id IS NULL
      AND p.settlement_date <= p_period_end
      AND NOT EXISTS (
        SELECT 1
        FROM private.booking_money_movements m
        WHERE m.payment_id = p.id
      )
      AND p.funds_holder IS NULL
  ) THEN
    RAISE EXCEPTION 'PAYMENT_FUNDS_CUSTODY_REQUIRED' USING ERRCODE = '55000';
  END IF;

  -- 2. Validate movement-backed payments and pending refund requests
  PERFORM private.assert_lounge_movements_reconciled(p_lounge_id, p_period_end);

  -- 3. Collect eligible legacy un-movemented payments
  SELECT
    COALESCE(array_agg(p.id ORDER BY p.id), ARRAY[]::uuid[]),
    COALESCE(sum(CASE WHEN p.funds_holder = 'platform' THEN p.net_to_lounge ELSE -p.commission END), 0)
  INTO v_legacy_ids, v_legacy_total
  FROM private.payment_settlement_values p
  WHERE p.lounge_id = p_lounge_id
    AND p.id = ANY(v_candidate_payment_ids)
    AND p.status = 'completed'
    AND p.payout_id IS NULL
    AND p.settlement_date <= p_period_end
    AND (p.funds_holder = 'lounge' OR p.settlement_date >= p_period_start)
    AND NOT EXISTS (
      SELECT 1
      FROM private.booking_money_movements m
      WHERE m.payment_id = p.id
    )
    AND NOT EXISTS (
      SELECT 1
      FROM private.cash_collection_receipts r
      JOIN public.bookings b ON b.id = r.booking_id
      WHERE r.booking_id = p.booking_id
        AND (b.status::text <> 'completed' OR b.payment_status IS DISTINCT FROM 'paid')
    );

  -- 4. Collect eligible canonical movements (including pre-payout refunds,
  --    post-payout refunds, and prior-period unsettled movements on finalized bookings)
  WITH base_movements AS (
    SELECT m.*
    FROM private.movement_settlement_values m
    WHERE m.lounge_id = p_lounge_id
      AND m.payment_id = ANY(v_candidate_payment_ids)
      AND NOT m.is_settled
      AND m.booking_finalized IS TRUE
      AND m.settlement_date <= p_period_end
  ),
  -- Ensure any unsettled refund tied to a selected collection movement is included
  -- even if its timestamp fell after p_period_end, so a collection is never
  -- paid out for more than its current net unrefunded balance.
  eligible_movements AS (
    SELECT bm.movement_id, bm.payment_id, bm.contribution_minor
    FROM base_movements bm
    UNION
    SELECT m_ref.movement_id, m_ref.payment_id, m_ref.contribution_minor
    FROM private.movement_settlement_values m_ref
    JOIN base_movements bm_orig ON m_ref.reversal_of = bm_orig.movement_id
    WHERE NOT m_ref.is_settled
  )
  SELECT
    COALESCE(array_agg(em.movement_id ORDER BY em.movement_id), ARRAY[]::uuid[]),
    COALESCE(array_agg(DISTINCT em.payment_id ORDER BY em.payment_id), ARRAY[]::uuid[]),
    count(*)::bigint,
    COALESCE(sum(em.contribution_minor), 0)::bigint
  INTO v_movement_ids, v_movement_payment_ids, v_movement_count, v_movement_total_minor
  FROM eligible_movements em;

  v_all_payment_ids := v_legacy_ids || v_movement_payment_ids;
  v_count := COALESCE(array_length(v_all_payment_ids, 1), 0);
  v_total := round(v_legacy_total + (v_movement_total_minor::numeric / 100), 2);

  IF v_count = 0 OR v_total <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_POSITIVE_SETTLEMENT_BALANCE');
  END IF;

  INSERT INTO public.payouts(
    lounge_id,
    period_start,
    period_end,
    total_amount,
    status,
    created_by
  )
  VALUES (
    p_lounge_id,
    p_period_start,
    p_period_end,
    v_total,
    'pending',
    auth.uid()
  )
  RETURNING id INTO v_payout;

  -- Insert movement-level payout entries first (immutable movement audit trail)
  IF v_movement_count > 0 THEN
    INSERT INTO private.booking_movement_payout_entries(
      payout_id,
      movement_id,
      contribution_minor
    )
    SELECT
      v_payout,
      m.movement_id,
      m.contribution_minor
    FROM private.movement_settlement_values m
    WHERE m.movement_id = ANY(v_movement_ids)
    ORDER BY m.movement_id;

    -- Insert per-payment settlement snapshot for the movements settled in this payout
    INSERT INTO private.payout_settlement_entries(
      payout_id,
      payment_id,
      lounge_id,
      funds_holder,
      payment_method,
      amount,
      commission,
      net_to_lounge,
      contribution
    )
    SELECT
      v_payout,
      m.payment_id,
      p_lounge_id,
      CASE
        WHEN bool_or(m.funds_holder = 'platform') THEN 'platform'
        ELSE 'lounge'
      END AS funds_holder,
      CASE
        WHEN count(DISTINCT m.payment_method) > 1 THEN 'mixed'
        ELSE min(m.payment_method)
      END AS payment_method,
      round(sum(m.amount_minor)::numeric / 100, 2) AS amount,
      round(sum(m.commission_minor)::numeric / 100, 2) AS commission,
      round(sum(m.net_to_lounge_minor)::numeric / 100, 2) AS net_to_lounge,
      round(sum(m.contribution_minor)::numeric / 100, 2) AS contribution
    FROM private.movement_settlement_values m
    WHERE m.movement_id = ANY(v_movement_ids)
    GROUP BY m.payment_id
    ORDER BY m.payment_id;
  END IF;

  -- Insert legacy un-movemented payment settlement entries
  IF COALESCE(array_length(v_legacy_ids, 1), 0) > 0 THEN
    INSERT INTO private.payout_settlement_entries(
      payout_id,
      payment_id,
      lounge_id,
      funds_holder,
      payment_method,
      amount,
      commission,
      net_to_lounge,
      contribution
    )
    SELECT
      v_payout,
      p.id,
      p.lounge_id,
      p.funds_holder,
      p.payment_method,
      p.amount,
      p.commission,
      p.net_to_lounge,
      CASE WHEN p.funds_holder = 'platform' THEN p.net_to_lounge ELSE -p.commission END
    FROM private.payment_settlement_values p
    WHERE p.id = ANY(v_legacy_ids)
    ORDER BY p.id;
  END IF;

  UPDATE public.payments
  SET payout_id = v_payout
  WHERE id = ANY(v_all_payment_ids);

  PERFORM private.assert_payout_settlement(v_payout);

  RETURN jsonb_build_object(
    'success', true,
    'payout_id', v_payout,
    'amount', v_total,
    'payment_count', v_count,
    'movement_count', v_movement_count
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.create_payout(uuid, date, date)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_payout(uuid, date, date)
  TO authenticated;

-- When a payout is cancelled or fails, restore each payment's payout_id to its
-- most recent prior 'paid' payout (if any), or NULL if never previously paid.
CREATE OR REPLACE FUNCTION private.release_cancelled_payout_payments(p_payout_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.payments p
  SET payout_id = (
    SELECT e.payout_id
    FROM private.payout_settlement_entries e
    JOIN public.payouts po ON po.id = e.payout_id
    WHERE e.payment_id = p.id
      AND e.payout_id <> p_payout_id
      AND po.status = 'paid'
    ORDER BY po.paid_at DESC NULLS LAST, po.id DESC
    LIMIT 1
  )
  WHERE p.payout_id = p_payout_id;
END;
$function$;

REVOKE ALL ON FUNCTION private.release_cancelled_payout_payments(uuid)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.cancel_payout(p_payout_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM private.assert_payout_admin();

  UPDATE public.payouts
  SET status = 'cancelled',
      cancelled_by = auth.uid(),
      cancelled_at = now(),
      cancelled_reason = p_reason
  WHERE id = p_payout_id
    AND status IN ('pending', 'approved', 'failed', 'needs_review');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout not found or cannot be cancelled';
  END IF;

  PERFORM private.release_cancelled_payout_payments(p_payout_id);

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'cancelled');
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_payout(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_payout(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.fail_payout(p_payout_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM private.assert_payout_admin();

  UPDATE public.payouts
  SET status = 'failed',
      failure_reason = p_reason
  WHERE id = p_payout_id
    AND status IN ('approved', 'processing');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout not found or not processing';
  END IF;

  PERFORM private.release_cancelled_payout_payments(p_payout_id);

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'failed');
END;
$function$;

REVOKE ALL ON FUNCTION public.fail_payout(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fail_payout(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.resolve_payout_review(
  p_payout_id uuid,
  p_resolution text,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_lounge_id uuid;
  v_amount numeric;
  v_owner_id uuid;
  v_lounge_name text;
BEGIN
  PERFORM private.assert_payout_admin();
  IF p_resolution NOT IN ('approve', 'cancel') THEN
    RAISE EXCEPTION 'Invalid resolution';
  END IF;
  IF NULLIF(trim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'Review reason is required';
  END IF;

  IF p_resolution = 'approve' THEN
    PERFORM private.assert_payout_settlement(p_payout_id);
    UPDATE public.payouts
    SET status = 'pending',
        notes = concat_ws(E'\n', notes, 'Review resolved: ' || p_reason)
    WHERE id = p_payout_id AND status = 'needs_review';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Payout not found or not awaiting review';
    END IF;
  ELSE
    UPDATE public.payouts
    SET status = 'cancelled',
        cancelled_by = auth.uid(),
        cancelled_at = now(),
        cancelled_reason = p_reason
    WHERE id = p_payout_id AND status = 'needs_review'
    RETURNING lounge_id, total_amount INTO v_lounge_id, v_amount;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Payout not found or not awaiting review';
    END IF;

    PERFORM private.release_cancelled_payout_payments(p_payout_id);

    IF v_lounge_id IS NOT NULL THEN
      SELECT owner_id, COALESCE(name_ar, name_en, name, 'الصالة')
      INTO v_owner_id, v_lounge_name
      FROM public.lounges
      WHERE id = v_lounge_id;

      IF v_owner_id IS NOT NULL THEN
        INSERT INTO public.notifications (
          user_id, lounge_id, title_ar, title_en, body_ar, body_en, type, is_read, metadata
        ) VALUES (
          v_owner_id, v_lounge_id,
          'تم رفض/إلغاء طلب سحب الأرباح ⚠️', 'Payout Request Cancelled ⚠️',
          'تم رفض طلب سحب أرباح صالة ' || v_lounge_name || ' بمبلغ ' || v_amount || ' ج.م. السبب: ' || p_reason,
          'Payout request of ' || v_amount || ' EGP for ' || v_lounge_name || ' was rejected. Reason: ' || p_reason,
          'payout', false,
          jsonb_build_object('payout_id', p_payout_id, 'reason', p_reason, 'amount', v_amount)
        );
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'payout_id', p_payout_id,
    'status', CASE WHEN p_resolution = 'approve' THEN 'pending' ELSE 'cancelled' END
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.resolve_payout_review(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_payout_review(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_payout_details(p_payout_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  PERFORM private.assert_payout_admin();

  SELECT jsonb_build_object(
    'payout', to_jsonb(po),
    'lounge', jsonb_build_object(
      'id', l.id,
      'name', l.name,
      'name_ar', l.name_ar,
      'name_en', l.name_en
    ),
    'payments', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', e.payment_id,
          'payout_id', e.payout_id,
          'lounge_id', e.lounge_id,
          'funds_holder', e.funds_holder,
          'payment_method', e.payment_method,
          'amount', e.amount,
          'commission', e.commission,
          'net_to_lounge', e.net_to_lounge,
          'contribution', e.contribution,
          'current_payment_status', p.status,
          'current_payment_amount', p.amount
        )
        ORDER BY e.payment_id
      )
      FROM private.payout_settlement_entries e
      LEFT JOIN public.payments p ON p.id = e.payment_id
      WHERE e.payout_id = po.id
    ), '[]'::jsonb),
    'movement_entries', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'movement_id', m.id,
          'booking_id', m.booking_id,
          'payment_id', m.payment_id,
          'movement_type', m.movement_type,
          'collection_purpose', m.collection_purpose,
          'payment_method', m.payment_method,
          'funds_holder', m.funds_holder,
          'amount_minor', m.amount_minor,
          'commission_minor', m.commission_minor,
          'net_to_lounge_minor', m.net_to_lounge_minor,
          'contribution_minor', bmpe.contribution_minor,
          'reversal_of', m.reversal_of,
          'verified_at', m.verified_at
        )
        ORDER BY m.verified_at, m.id
      )
      FROM private.booking_movement_payout_entries bmpe
      JOIN private.booking_money_movements m ON m.id = bmpe.movement_id
      WHERE bmpe.payout_id = po.id
    ), '[]'::jsonb),
    'reconciliation', jsonb_build_object(
      'has_settlement_snapshot', EXISTS (
        SELECT 1 FROM private.payout_settlement_entries e WHERE e.payout_id = po.id
      ),
      'unknown_custody_count', (
        SELECT count(*)
        FROM private.payment_settlement_values p
        WHERE p.payout_id = po.id
          AND p.funds_holder IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM private.booking_money_movements m WHERE m.payment_id = p.id
          )
      ),
      'payment_count', (
        SELECT count(*) FROM private.payout_settlement_entries e WHERE e.payout_id = po.id
      ),
      'movement_count', (
        SELECT count(*) FROM private.booking_movement_payout_entries bmpe WHERE bmpe.payout_id = po.id
      ),
      'completed_count', (
        SELECT count(*)
        FROM private.payout_settlement_entries e
        JOIN public.payments p ON p.id = e.payment_id
        WHERE e.payout_id = po.id
          AND (po.status = 'paid' OR p.status IN ('completed', 'refunded'))
          AND e.amount >= 0
      ),
      'refunded_count', (
        SELECT count(*)
        FROM private.payout_settlement_entries e
        JOIN public.payments p ON p.id = e.payment_id
        WHERE e.payout_id = po.id
          AND (e.amount < 0 OR (po.status <> 'paid' AND p.status = 'refunded'))
      ),
      'calculated_net', COALESCE((
        SELECT sum(e.contribution)
        FROM private.payout_settlement_entries e
        WHERE e.payout_id = po.id
      ), 0),
      'difference', po.total_amount - COALESCE((
        SELECT sum(e.contribution)
        FROM private.payout_settlement_entries e
        WHERE e.payout_id = po.id
      ), 0)
    )
  ) INTO v_result
  FROM public.payouts po
  JOIN public.lounges l ON l.id = po.lounge_id
  WHERE po.id = p_payout_id;

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Payout not found';
  END IF;
  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_payout_details(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_payout_details(uuid) TO authenticated;
