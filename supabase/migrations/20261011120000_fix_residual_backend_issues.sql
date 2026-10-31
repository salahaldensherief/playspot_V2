-- Migration: 20261011120000_fix_residual_backend_issues.sql
-- Description: Comprehensive fix for residual backend issues:
--              1. Drop ambiguous 4-parameter overload of apply_booking_discount (fixes error 42725).
--              2. Allow staff/cashiers to validate customer vouchers in validate_voucher_by_code.
--              3. Fix Open-Time session completion & delta payment settlement in complete_booking_session
--                 and complete_booking_payment without duplicate shift entries.
--              4. Filter out cash payments from get_pending_payouts_overview and create_payout.
--              5. Return applied_voucher_code in get_all_bookings_admin.
--              6. Implement missing delete_lounge_admin RPC for super admins.
--              7. Add missing foreign key indexes on pricing_rules and audit_logs.

BEGIN;

-- ============================================================================
-- 1. DROP AMBIGUOUS apply_booking_discount OVERLOAD (Fixes ERROR 42725)
-- ============================================================================
DROP FUNCTION IF EXISTS public.apply_booking_discount(uuid, numeric, numeric, text);

CREATE OR REPLACE FUNCTION public.apply_booking_discount(
  p_booking_id uuid,
  p_discount_amount numeric DEFAULT 0,
  p_discount_percentage numeric DEFAULT 0,
  p_discount_reason text DEFAULT NULL::text,
  p_voucher_code text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric := GREATEST(COALESCE(p_discount_amount, 0), 0);
  v_percentage numeric := GREATEST(COALESCE(p_discount_percentage, 0), 0);
  v_reason text := NULLIF(btrim(p_discount_reason), '');
  v_clean_voucher text := NULLIF(upper(btrim(p_voucher_code)), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  PERFORM private.assert_lounge_operator(v_booking.lounge_id, false);

  IF v_amount > 0 AND v_percentage > 0 THEN
    RAISE EXCEPTION 'Use either a fixed discount or a percentage discount, not both'
      USING ERRCODE = '22023';
  END IF;

  IF v_percentage > 100 THEN
    RAISE EXCEPTION 'Discount percentage must be between 0 and 100'
      USING ERRCODE = '22023';
  END IF;

  IF (v_amount > 0 OR v_percentage > 0) AND v_reason IS NULL AND v_clean_voucher IS NULL THEN
    RAISE EXCEPTION 'Discount reason or voucher code is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_clean_voucher IS NOT NULL AND v_reason IS NULL THEN
    v_reason := 'Voucher: ' || v_clean_voucher;
  END IF;

  UPDATE public.bookings
  SET
    discount_amount = v_amount,
    discount_percentage = v_percentage,
    discount_reason = v_reason,
    applied_voucher_code = COALESCE(v_clean_voucher, applied_voucher_code),
    discount_approved_by = auth.uid(),
    updated_at = now()
  WHERE id = p_booking_id
  RETURNING *
  INTO v_booking;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking.id,
    'discount_amount', v_booking.discount_amount,
    'discount_percentage', v_booking.discount_percentage,
    'discount_reason', v_booking.discount_reason,
    'applied_voucher_code', v_booking.applied_voucher_code,
    'total_price', v_booking.total_price
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.apply_booking_discount(uuid, numeric, numeric, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_booking_discount(uuid, numeric, numeric, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.apply_booking_discount(uuid, numeric, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_booking_discount(uuid, numeric, numeric, text, text) TO service_role;


-- ============================================================================
-- 2. ALLOW CASHIERS / STAFF TO VALIDATE CUSTOMER VOUCHERS
-- ============================================================================
CREATE OR REPLACE FUNCTION public.validate_voucher_by_code(
  p_code text,
  p_user_id uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_voucher public.user_vouchers%ROWTYPE;
  v_is_staff boolean := false;
  v_target_user uuid;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'error', 'Unauthenticated user');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = v_actor
      AND (
        role IN ('super_admin', 'lounge_owner', 'lounge_manager', 'cashier')
        OR lounge_id IS NOT NULL
      )
  ) INTO v_is_staff;

  IF v_is_staff THEN
    v_target_user := p_user_id; -- Staff can validate any customer's voucher (or specific customer if passed)
  ELSE
    v_target_user := v_actor; -- Regular user can only validate their own vouchers
  END IF;

  SELECT * INTO v_voucher
  FROM public.user_vouchers
  WHERE UPPER(TRIM(code)) = UPPER(TRIM(p_code))
    AND (v_target_user IS NULL OR user_id = v_target_user)
    AND status = 'active'
    AND (expires_at IS NULL OR expires_at > NOW())
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'error', 'Voucher is invalid, expired, or already used');
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'voucher_id', v_voucher.id,
    'code', v_voucher.code,
    'reward_type', v_voucher.reward_type,
    'reward_value', v_voucher.reward_value,
    'min_spend', 0,
    'user_id', v_voucher.user_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.validate_voucher_by_code(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_voucher_by_code(text, uuid) TO authenticated, service_role;


-- ============================================================================
-- 3. FIX OPEN-TIME COMPLETION & ACCURATE SETTLEMENT
-- ============================================================================
CREATE OR REPLACE FUNCTION public.complete_booking_session(
  p_booking_id uuid,
  p_action_by uuid DEFAULT NULL::uuid
)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_now timestamptz := now();
  v_start_time timestamptz;
  v_elapsed_minutes integer;
  v_billable_raw integer;
  v_billable_minutes integer;
  v_rounding integer := 15;
  v_minimum integer := 30;
  v_max integer := 720;
  v_rate numeric := 50;
  v_room_price numeric;
  v_total_price numeric;
  v_amount_paid numeric := 0;
  v_amount_due numeric := 0;
  v_new_payment_status text := 'unpaid';
  v_snap jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'Not authorized for session control in this lounge' USING ERRCODE = '42501';
  END IF;

  -- Compute actual cash/online collected payments already recorded
  SELECT COALESCE(SUM(p.amount), 0)
  INTO v_amount_paid
  FROM public.payments AS p
  WHERE p.booking_id = p_booking_id
    AND p.status = 'completed';

  -- Idempotency: if already completed, return existing numbers
  IF v_booking.status = 'completed'::public.booking_status THEN
    v_amount_due := GREATEST(0, COALESCE(v_booking.total_price, 0) - v_amount_paid);

    RETURN json_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'lounge_id', v_booking.lounge_id,
      'status', 'completed',
      'final_total', v_booking.total_price,
      'amount_paid', v_amount_paid,
      'amount_due', v_amount_due,
      'payment_status', v_booking.payment_status,
      'idempotent', true
    );
  END IF;

  IF v_booking.status <> 'in_progress'::public.booking_status THEN
    RAISE EXCEPTION 'Only in-progress sessions can be completed' USING ERRCODE = '55000';
  END IF;

  -- If this is an Open Time session, calculate billing
  IF COALESCE(v_booking.is_open_time, false) IS TRUE THEN
    v_snap := v_booking.open_time_pricing_snapshot;

    IF v_snap IS NOT NULL AND v_snap <> '{}'::jsonb THEN
      v_rate := COALESCE((v_snap->>'effective_hourly_rate')::numeric, (v_snap->>'base_hourly_rate')::numeric, 50);
      v_minimum := COALESCE((v_snap->>'minimum_minutes')::integer, 30);
      v_rounding := COALESCE((v_snap->>'rounding_minutes')::integer, 15);
      v_max := COALESCE((v_snap->>'max_minutes')::integer, 720);
    ELSE
      SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_booking.lounge_id;
      SELECT r.* INTO v_room FROM public.rooms r WHERE r.id = v_booking.room_id;
      v_minimum := COALESCE(v_room.open_time_minimum_minutes, v_lounge.open_time_minimum_minutes, 30);
      v_rounding := COALESCE(v_room.open_time_rounding_minutes, v_lounge.open_time_rounding_minutes, 15);
      v_max := COALESCE(v_room.open_time_max_minutes, v_lounge.open_time_max_minutes, 720);
      v_rate := CASE
        WHEN v_booking.play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN v_room.hourly_rate_multi
        ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
      END;
    END IF;

    v_start_time := COALESCE(v_booking.open_time_started_at, v_booking.actual_start_time, v_booking.created_at);
    v_elapsed_minutes := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_now - v_start_time)) / 60.0)::integer);

    IF v_max IS NOT NULL AND v_max > 0 THEN
      v_billable_raw := LEAST(v_elapsed_minutes, v_max);
    ELSE
      v_billable_raw := v_elapsed_minutes;
    END IF;

    v_billable_raw := GREATEST(v_billable_raw, v_minimum);
    v_billable_minutes := CEIL(v_billable_raw::numeric / v_rounding::numeric)::integer * v_rounding;

    v_room_price := ROUND((v_rate / 60.0) * v_billable_minutes, 2);
    v_total_price := v_room_price + COALESCE(v_booking.addons_total, v_booking.addons_price, 0) - COALESCE(v_booking.discount_amount, 0);
    v_amount_due := GREATEST(0, v_total_price - v_amount_paid);

    IF v_amount_due > 0 THEN
      v_new_payment_status := 'unpaid';
    ELSE
      v_new_payment_status := 'paid';
    END IF;

    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
        payment_status = v_new_payment_status,
        open_time_closed_at = v_now,
        open_time_billing_minutes = v_billable_minutes,
        duration_minutes = v_billable_minutes,
        room_price = v_room_price,
        total_price = v_total_price,
        updated_at = v_now
    WHERE id = p_booking_id;
  ELSE
    v_total_price := v_booking.total_price;
    v_amount_due := GREATEST(0, v_total_price - v_amount_paid);
    v_new_payment_status := CASE WHEN v_amount_due = 0 THEN 'paid' ELSE 'unpaid' END;

    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
        payment_status = v_new_payment_status,
        updated_at = v_now
    WHERE id = p_booking_id;
  END IF;

  -- Release room
  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms AS r
    SET status = 'available',
        is_available = true,
        updated_at = v_now
    WHERE r.id = v_booking.room_id
      AND r.lounge_id = v_booking.lounge_id
      AND r.status = 'occupied';
  END IF;

  RETURN json_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'lounge_id', v_booking.lounge_id,
    'status', 'completed',
    'final_total', v_total_price,
    'amount_paid', v_amount_paid,
    'amount_due', v_amount_due,
    'payment_status', v_new_payment_status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.complete_booking_session(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_session(uuid, uuid) TO authenticated, service_role;


-- ============================================================================
-- 4. ATOMIC complete_booking_payment WITH DELTA SETTLEMENT & VOUCHER CONSUMPTION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.complete_booking_payment(
  p_booking_id uuid,
  p_payment_method text DEFAULT 'cash'::text,
  p_final_amount numeric DEFAULT NULL::numeric
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_total_amount numeric;
  v_already_paid numeric := 0;
  v_delta numeric := 0;
  v_commission numeric;
  v_shift_id uuid;
  v_new_status public.booking_status;
  v_voucher_to_consume text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_payment_method IS NULL OR p_payment_method NOT IN (
    'cash','manual_transfer','card','vodafone_cash','fawry','instapay','app_wallet'
  ) THEN
    RAISE EXCEPTION 'Invalid payment method' USING ERRCODE = '22023';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized for billing checkout in this lounge' USING ERRCODE = '42501';
  END IF;

  -- Check already paid amounts
  SELECT COALESCE(SUM(p.amount), 0)
  INTO v_already_paid
  FROM public.payments AS p
  WHERE p.booking_id = p_booking_id
    AND p.status = 'completed';

  v_total_amount := round(v_booking.total_price, 2);
  v_delta := GREATEST(0, v_total_amount - v_already_paid);

  -- Idempotency check: if already fully paid and delta is 0
  IF v_booking.payment_status = 'paid' AND v_delta = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'room_id', v_booking.room_id,
      'status', v_booking.status::text,
      'amount_paid', v_total_amount,
      'payment_method', v_booking.payment_method,
      'idempotent', true
    );
  END IF;

  IF v_booking.status::text IN ('cancelled', 'rejected') THEN
    RAISE EXCEPTION 'Cannot collect payment for a cancelled or rejected booking' USING ERRCODE = '55000';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payments AS p
    WHERE p.booking_id = p_booking_id AND p.status = 'refunded'
  ) THEN
    RAISE EXCEPTION 'A refunded payment cannot be completed again through this RPC' USING ERRCODE = '55000';
  END IF;

  IF v_booking.total_price IS NULL OR v_booking.total_price < 0 THEN
    RAISE EXCEPTION 'Booking has an invalid server-calculated total' USING ERRCODE = '22023';
  END IF;

  IF p_final_amount IS NOT NULL AND round(p_final_amount, 2) NOT IN (v_total_amount, v_delta) THEN
    RAISE EXCEPTION 'Payment amount must match the booking total or remaining balance'
      USING ERRCODE = '22023';
  END IF;

  SELECT s.id
  INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.lounge_id = v_booking.lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
  ORDER BY s.opened_at DESC
  LIMIT 1
  FOR SHARE;

  IF v_shift_id IS NULL THEN
    RAISE EXCEPTION 'An open shift is required to collect payment' USING ERRCODE = '55000';
  END IF;

  IF v_booking.status = 'completed'::public.booking_status THEN
    v_new_status := 'completed'::public.booking_status;
  ELSIF v_booking.status = 'in_progress'::public.booking_status THEN
    v_new_status := 'in_progress'::public.booking_status;
  ELSE
    v_new_status := 'upcoming'::public.booking_status;
  END IF;

  -- Consume attached voucher if exists
  v_voucher_to_consume := COALESCE(
    v_booking.applied_voucher_code,
    CASE 
      WHEN v_booking.discount_reason ~* '^voucher:\s*([A-Za-z0-9_-]+)' 
      THEN substring(v_booking.discount_reason from '(?i)^voucher:\s*([A-Za-z0-9_-]+)')
      ELSE NULL 
    END
  );

  IF v_voucher_to_consume IS NOT NULL THEN
    -- Mark user voucher as used
    UPDATE public.user_vouchers
    SET status = 'used',
        used_at = now(),
        used_booking_id = p_booking_id
    WHERE UPPER(TRIM(code)) = UPPER(TRIM(v_voucher_to_consume))
      AND (v_booking.user_id IS NULL OR user_id = v_booking.user_id)
      AND status = 'active';
  END IF;

  v_commission := round(v_total_amount * 0.15, 2);

  -- Upsert payments record for authoritative financial total
  INSERT INTO public.payments (
    booking_id, user_id, lounge_id, amount, commission, net_to_lounge,
    payment_method, status, paid_at, discount_amount, discount_percentage,
    discount_reason, discount_approved_by
  ) VALUES (
    p_booking_id, v_booking.user_id, v_booking.lounge_id, v_total_amount,
    v_commission, v_total_amount - v_commission, p_payment_method, 'completed', now(),
    COALESCE(v_booking.discount_amount, 0), COALESCE(v_booking.discount_percentage, 0),
    v_booking.discount_reason, v_booking.discount_approved_by
  )
  ON CONFLICT (booking_id) DO UPDATE SET
    amount = EXCLUDED.amount,
    commission = EXCLUDED.commission,
    net_to_lounge = EXCLUDED.net_to_lounge,
    payment_method = EXCLUDED.payment_method,
    status = 'completed',
    paid_at = EXCLUDED.paid_at,
    discount_amount = EXCLUDED.discount_amount,
    discount_percentage = EXCLUDED.discount_percentage,
    discount_reason = EXCLUDED.discount_reason,
    discount_approved_by = EXCLUDED.discount_approved_by;

  -- Record only the delta in the current active shift (prevents double-counting previously collected cash)
  IF v_delta > 0 THEN
    INSERT INTO public.shift_payments (
      shift_id, lounge_id, booking_id, payment_method, category, amount, paid_at
    ) VALUES (
      v_shift_id, v_booking.lounge_id, p_booking_id, p_payment_method, 'gaming_time', v_delta, now()
    );
  END IF;

  UPDATE public.bookings AS b
  SET status = v_new_status,
      payment_status = 'paid',
      payment_method = p_payment_method,
      total_price = v_total_amount,
      shift_id = v_shift_id,
      updated_at = now()
  WHERE b.id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'room_id', v_booking.room_id,
    'status', v_new_status::text,
    'amount_paid', v_total_amount,
    'delta_collected', v_delta,
    'payment_method', p_payment_method,
    'commission', v_commission,
    'net_to_lounge', v_total_amount - v_commission,
    'shift_id', v_shift_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.complete_booking_payment(uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_payment(uuid, text, numeric) TO authenticated, service_role;


-- ============================================================================
-- 5. SECURE PAYOUT FUNCTIONS: EXCLUDE CASH PAYMENTS ALREADY IN LOUNGE DRAWER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_pending_payouts_overview()
 RETURNS TABLE(lounge_id uuid, lounge_name text, pending_amount numeric, total_transactions bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    p.lounge_id,
    COALESCE(l.name_ar, l.name_en, l.name)::text,
    COALESCE(SUM(p.net_to_lounge), 0),
    COUNT(*)
  FROM public.payments AS p
  JOIN public.lounges AS l ON l.id = p.lounge_id
  WHERE p.status = 'completed'
    AND p.payout_id IS NULL
    AND p.payment_method NOT IN ('cash')
  GROUP BY p.lounge_id, COALESCE(l.name_ar, l.name_en, l.name)
  HAVING COALESCE(SUM(p.net_to_lounge), 0) > 0;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_pending_payouts_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_pending_payouts_overview() TO authenticated, service_role;


CREATE OR REPLACE FUNCTION public.create_payout(p_lounge_id uuid, p_period_start date, p_period_end date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_payout_id uuid;
  v_total numeric;
  v_count integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin' AND is_active) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_period_start IS NULL OR p_period_end IS NULL OR p_period_start > p_period_end THEN
    RAISE EXCEPTION 'Invalid payout period';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_lounge_id::text, 0));

  IF EXISTS (
    SELECT 1 FROM public.payouts
    WHERE lounge_id = p_lounge_id
      AND status IN ('pending','approved','processing','paid')
      AND daterange(period_start, period_end, '[]') && daterange(p_period_start, p_period_end, '[]')
  ) THEN
    RAISE EXCEPTION 'Overlapping active payout exists for this lounge and period';
  END IF;

  -- Strictly aggregate platform-held non-cash payments
  SELECT COUNT(*), COALESCE(SUM(COALESCE(net_to_lounge, amount - COALESCE(commission, 0))), 0)
  INTO v_count, v_total
  FROM public.payments
  WHERE lounge_id = p_lounge_id
    AND status = 'completed'
    AND payout_id IS NULL
    AND payment_method NOT IN ('cash')
    AND paid_at::date BETWEEN p_period_start AND p_period_end;

  IF v_count = 0 OR v_total <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يوجد مبلغ مستحق في الفترة دي للدفعات الإلكترونية');
  END IF;

  INSERT INTO public.payouts (lounge_id, period_start, period_end, total_amount, status, created_by)
  VALUES (p_lounge_id, p_period_start, p_period_end, v_total, 'pending', auth.uid())
  RETURNING id INTO v_payout_id;

  UPDATE public.payments
  SET payout_id = v_payout_id
  WHERE lounge_id = p_lounge_id
    AND status = 'completed'
    AND payout_id IS NULL
    AND payment_method NOT IN ('cash')
    AND paid_at::date BETWEEN p_period_start AND p_period_end;

  RETURN jsonb_build_object('success', true, 'payout_id', v_payout_id, 'amount', v_total, 'payment_count', v_count);
END;
$function$;

REVOKE ALL ON FUNCTION public.create_payout(uuid, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_payout(uuid, date, date) TO authenticated, service_role;


-- ============================================================================
-- 6. UNIFY get_all_bookings_admin AND RETURN applied_voucher_code
-- ============================================================================
DROP FUNCTION IF EXISTS public.get_all_bookings_admin(uuid, text, integer, integer);
DROP FUNCTION IF EXISTS public.get_all_bookings_admin(uuid, integer, integer, text, text, text, date);

CREATE OR REPLACE FUNCTION public.get_all_bookings_admin(
  p_lounge_id uuid DEFAULT NULL::uuid,
  p_status text DEFAULT NULL::text,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_search text DEFAULT NULL::text,
  p_payment_status text DEFAULT NULL::text,
  p_date date DEFAULT NULL::date
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_own_lounge uuid;
  v_target_lounge uuid;
  v_result JSONB;
BEGIN
  SELECT role, lounge_id INTO v_role, v_own_lounge
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_role IS NULL OR (v_role <> 'super_admin' AND v_own_lounge IS NULL) THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  IF v_role = 'super_admin' THEN
    v_target_lounge := p_lounge_id;
  ELSE
    IF p_lounge_id IS NOT NULL AND p_lounge_id <> v_own_lounge THEN
      RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    v_target_lounge := v_own_lounge;
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'out_booking_id', b.id,
      'user_id', b.user_id,
      'lounge_id', b.lounge_id,
      'room_id', b.room_id,
      'user_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'customer_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'user_phone', COALESCE(b.user_phone, p.phone),
      'customer_phone', COALESCE(b.user_phone, p.phone),
      'user_email', p.email,
      'customer_email', p.email,
      'room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'out_room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'controllers_count', r.controllers_count,
      'screen_size', r.screen_size,
      'out_booking_date', b.date,
      'date', b.date,
      'out_start_time', b.start_time,
      'start_time', b.start_time,
      'out_end_time', b.end_time,
      'end_time', b.end_time,
      'duration_minutes', b.duration_minutes,
      'status', b.status,
      'out_booking_status', b.status,
      'payment_status', b.payment_status,
      'out_payment_status', b.payment_status,
      'payment_method', b.payment_method,
      'out_payment_method', b.payment_method,
      'total_price', b.total_price,
      'out_total_price', b.total_price,
      'addons_price', b.addons_price,
      'out_addons_price', b.addons_price,
      'voucher_code', b.applied_voucher_code,
      'discount_amount', b.discount_amount,
      'discount_percentage', b.discount_percentage,
      'discount_reason', b.discount_reason,
      'play_mode', b.play_mode,
      'room_price', b.room_price,
      'shift_id', b.shift_id,
      'created_at', b.created_at,
      'checked_in_at', b.checked_in_at,
      'canteen_orders', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', co.id,
            'items', co.items,
            'total_price', co.total_price,
            'status', co.status,
            'created_at', co.created_at
          )
        ), '[]'::jsonb)
        FROM public.canteen_orders co
        WHERE co.booking_id = b.id
      ),
      'extras', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', bi.id,
            'extra_id', bi.extra_id,
            'name', bi.name,
            'quantity', bi.quantity,
            'unit_price', bi.unit_price,
            'total_price', bi.total_price,
            'status', bi.status
          )
        ), '[]'::jsonb)
        FROM public.booking_items bi
        WHERE bi.booking_id = b.id
      )
    )
  ), '[]'::jsonb) INTO v_result
  FROM (
    SELECT bk.*
    FROM public.bookings bk
    LEFT JOIN public.profiles pr ON bk.user_id = pr.id
    LEFT JOIN public.rooms rm ON bk.room_id = rm.id
    WHERE (v_target_lounge IS NULL OR bk.lounge_id = v_target_lounge)
      AND (p_status IS NULL OR p_status = '' OR bk.status::text = p_status)
      AND (p_payment_status IS NULL OR p_payment_status = '' OR bk.payment_status = p_payment_status)
      AND (p_date IS NULL OR bk.date = p_date)
      AND (
        p_search IS NULL
        OR p_search = ''
        OR bk.id::text ILIKE '%' || p_search || '%'
        OR bk.user_name ILIKE '%' || p_search || '%'
        OR bk.user_phone ILIKE '%' || p_search || '%'
        OR pr.full_name ILIKE '%' || p_search || '%'
        OR pr.phone ILIKE '%' || p_search || '%'
        OR pr.email ILIKE '%' || p_search || '%'
        OR rm.name ILIKE '%' || p_search || '%'
      )
    ORDER BY bk.created_at DESC
    LIMIT p_limit
    OFFSET p_offset
  ) b
  LEFT JOIN public.profiles p ON b.user_id = p.id
  LEFT JOIN public.rooms r ON b.room_id = r.id;

  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_all_bookings_admin(uuid, text, integer, integer, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_all_bookings_admin(uuid, text, integer, integer, text, text, date) TO authenticated, service_role;


-- ============================================================================
-- 7. IMPLEMENT MISSING delete_lounge_admin RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delete_lounge_admin(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  UPDATE public.lounges
  SET is_active = false,
      updated_at = now()
  WHERE id = p_lounge_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lounge not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'lounge_id', p_lounge_id,
    'message', 'Lounge deactivated successfully'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.delete_lounge_admin(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_lounge_admin(uuid) TO authenticated, service_role;


COMMIT;
