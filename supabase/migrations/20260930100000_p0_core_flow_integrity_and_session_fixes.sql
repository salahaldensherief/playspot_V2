BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ============================================================================
-- 1. Ensure Lounge Timezone & Business Date Helper
-- ============================================================================
ALTER TABLE public.lounges
  ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'Africa/Cairo';

CREATE OR REPLACE FUNCTION public.business_date(
  p_lounge_id uuid,
  p_ts timestamptz DEFAULT now()
)
RETURNS date
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_tz text;
  v_opening_time time without time zone;
  v_closing_time time without time zone;
  v_local_ts timestamp without time zone;
  v_local_date date;
  v_local_time time without time zone;
BEGIN
  SELECT
    COALESCE(NULLIF(btrim(l.timezone), ''), 'Africa/Cairo'),
    l.opening_time,
    l.closing_time
  INTO v_tz, v_opening_time, v_closing_time
  FROM public.lounges AS l
  WHERE l.id = p_lounge_id;

  IF v_tz IS NULL THEN
    v_tz := 'Africa/Cairo';
  END IF;

  v_local_ts := COALESCE(p_ts, now()) AT TIME ZONE v_tz;
  v_local_date := v_local_ts::date;
  v_local_time := v_local_ts::time;

  -- Handle operating hours crossing midnight (e.g. 10:00 AM to 03:00 AM next day)
  IF v_opening_time IS NOT NULL AND v_closing_time IS NOT NULL THEN
    IF v_closing_time <= v_opening_time THEN
      IF v_local_time < v_closing_time THEN
        RETURN (v_local_date - INTERVAL '1 day')::date;
      END IF;
    END IF;
  END IF;

  RETURN v_local_date;
END;
$$;

REVOKE ALL ON FUNCTION public.business_date(uuid, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.business_date(uuid, timestamptz) TO authenticated, service_role;

-- ============================================================================
-- 2. Shift Association Trigger: Fix checked_in_at Gap & Race Conditions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.attach_booking_to_active_shift()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
  v_shift_id uuid;
  v_shift_lounge_id uuid;
  v_shift_status text;
  v_requires_open_shift boolean :=
    NEW.status::text = 'in_progress' 
    OR NEW.actual_start_time IS NOT NULL 
    OR NEW.checked_in_at IS NOT NULL;
BEGIN
  -- If active booking needs a shift and none is assigned, find the active shift for this lounge
  IF v_requires_open_shift
     AND NEW.shift_id IS NULL
     AND NEW.lounge_id IS NOT NULL THEN
    SELECT s.id
    INTO v_shift_id
    FROM public.shifts AS s
    WHERE s.lounge_id = NEW.lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
    ORDER BY s.opened_at DESC
    LIMIT 1
    FOR SHARE;

    IF v_shift_id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'NO_OPEN_SHIFT';
    END IF;

    NEW.shift_id := v_shift_id;
  END IF;

  -- If shift_id is provided, validate it belongs to the same lounge and is valid
  IF NEW.shift_id IS NOT NULL THEN
    SELECT s.lounge_id, s.status
    INTO v_shift_lounge_id, v_shift_status
    FROM public.shifts AS s
    WHERE s.id = NEW.shift_id
    FOR SHARE;

    IF v_shift_lounge_id IS NULL THEN
      RAISE EXCEPTION 'The selected shift does not exist.' USING ERRCODE = '22023';
    END IF;

    IF NEW.lounge_id IS DISTINCT FROM v_shift_lounge_id THEN
      RAISE EXCEPTION 'Booking and shift must belong to the same lounge.' USING ERRCODE = '22023';
    END IF;

    IF v_requires_open_shift AND v_shift_status <> 'open' THEN
      RAISE EXCEPTION 'An active booking must be linked to an open shift.' USING ERRCODE = '55000';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS attach_booking_to_active_shift_trigger ON public.bookings;
CREATE TRIGGER attach_booking_to_active_shift_trigger
BEFORE INSERT OR UPDATE OF shift_id, status, actual_start_time, checked_in_at, lounge_id
ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.attach_booking_to_active_shift();

-- ============================================================================
-- 3. Hardened complete_booking_payment: Permission, Shift & Post-Pay Support
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
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric;
  v_commission numeric;
  v_shift_id uuid;
  v_new_status public.booking_status;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_payment_method IS NULL OR p_payment_method NOT IN (
    'cash','manual_transfer','card','vodafone_cash','fawry','instapay','app_wallet','pos'
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

  -- Verify billing_checkout permission rather than mere lounge membership
  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized for billing checkout in this lounge' USING ERRCODE = '42501';
  END IF;

  -- Idempotency check: if already marked paid, return success without duplicate entries
  IF v_booking.payment_status = 'paid' THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'room_id', v_booking.room_id,
      'status', v_booking.status::text,
      'amount_paid', v_booking.total_price,
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

  IF p_final_amount IS NOT NULL AND round(p_final_amount, 2) <> round(v_booking.total_price, 2) THEN
    RAISE EXCEPTION 'Payment amount must match the booking total; update an approved discount before collecting'
      USING ERRCODE = '22023';
  END IF;

  v_amount := round(v_booking.total_price, 2);
  v_commission := round(v_amount * 0.15, 2);

  -- Mandatory active shift for the same lounge
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

  -- Status preservation: never downgrade a completed session
  IF v_booking.status = 'completed'::public.booking_status THEN
    v_new_status := 'completed'::public.booking_status;
  ELSIF v_booking.status = 'in_progress'::public.booking_status THEN
    v_new_status := 'in_progress'::public.booking_status;
  ELSE
    v_new_status := 'upcoming'::public.booking_status;
  END IF;

  -- Atomic payment recording
  INSERT INTO public.payments (
    booking_id, user_id, lounge_id, amount, commission, net_to_lounge,
    payment_method, status, paid_at, discount_amount, discount_percentage,
    discount_reason, discount_approved_by
  ) VALUES (
    p_booking_id, v_booking.user_id, v_booking.lounge_id, v_amount,
    v_commission, v_amount - v_commission, p_payment_method, 'completed', now(),
    COALESCE(v_booking.discount_amount, 0), COALESCE(v_booking.discount_percentage, 0),
    v_booking.discount_reason, v_booking.discount_approved_by
  )
  ON CONFLICT (booking_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    lounge_id = EXCLUDED.lounge_id,
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

  -- Record shift payment atomically
  INSERT INTO public.shift_payments (
    shift_id, lounge_id, booking_id, payment_method, category, amount, paid_at
  ) VALUES (
    v_shift_id, v_booking.lounge_id, p_booking_id, p_payment_method, 'gaming_time', v_amount, now()
  );

  -- Update booking atomically
  UPDATE public.bookings AS b
  SET status = v_new_status,
      payment_status = 'paid',
      payment_method = p_payment_method,
      total_price = v_amount,
      shift_id = v_shift_id,
      updated_at = now()
  WHERE b.id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'room_id', v_booking.room_id,
    'status', v_new_status::text,
    'amount_paid', v_amount,
    'payment_method', p_payment_method,
    'commission', v_commission,
    'net_to_lounge', v_amount - v_commission,
    'shift_id', v_shift_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_booking_payment(uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_payment(uuid, text, numeric) TO authenticated, service_role;

-- ============================================================================
-- 4. Tournament Payment Submission: Overload Lockdown & Explicit Security
-- ============================================================================

-- Lock down 6-parameter overload to service_role and super_admin only
REVOKE ALL ON FUNCTION public.submit_tournament_payment(uuid, uuid, uuid, numeric, text, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_tournament_payment(uuid, uuid, uuid, numeric, text, text)
TO service_role;

-- Harden 4-parameter participant payment submission
CREATE OR REPLACE FUNCTION public.submit_tournament_payment(
  p_participant_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_receipt_url text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_p public.tournament_participants%ROWTYPE;
  v_t public.tournaments%ROWTYPE;
  v_s public.tournament_payment_submissions%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_participant_id IS NULL THEN
    RAISE EXCEPTION 'Participant ID is required' USING ERRCODE = '22023';
  END IF;

  SELECT p.*
  INTO v_p
  FROM public.tournament_participants AS p
  WHERE p.id = p_participant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Participant registration not found' USING ERRCODE = 'P0002';
  END IF;

  -- Explicit caller ownership check
  IF v_p.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Not authorized: You can only submit payment for your own participation'
      USING ERRCODE = '42501';
  END IF;

  SELECT t.*
  INTO v_t
  FROM public.tournaments AS t
  WHERE t.id = v_p.tournament_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournament not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_p.registration_status <> 'pending_payment'
     OR COALESCE(v_p.payment_status, 'unpaid') <> 'unpaid' THEN
    RAISE EXCEPTION 'Payment is not allowed in the current registration state' USING ERRCODE = '55000';
  END IF;

  IF v_p.payment_deadline IS NOT NULL AND v_p.payment_deadline < now() THEN
    RAISE EXCEPTION 'Payment deadline has expired' USING ERRCODE = '55000';
  END IF;

  IF p_payment_method NOT IN ('instapay', 'vodafone_cash') THEN
    RAISE EXCEPTION 'Invalid payment method: only instapay and vodafone_cash are accepted'
      USING ERRCODE = '22023';
  END IF;

  IF p_receipt_url IS NULL OR btrim(p_receipt_url) = '' THEN
    RAISE EXCEPTION 'Payment receipt URL is required' USING ERRCODE = '22023';
  END IF;

  IF p_amount IS NULL OR p_amount <> v_t.entry_fee THEN
    RAISE EXCEPTION 'Payment amount mismatch: expected entry fee of %', v_t.entry_fee
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.tournament_payment_submissions (
    participant_id, amount, payment_method, receipt_url, submitted_by
  ) VALUES (
    p_participant_id, p_amount, p_payment_method, p_receipt_url, auth.uid()
  )
  RETURNING * INTO v_s;

  UPDATE public.tournament_participants
  SET payment_status = 'pending',
      payment_method = p_payment_method,
      receipt_url = p_receipt_url,
      updated_at = now()
  WHERE id = p_participant_id
  RETURNING * INTO v_p;

  PERFORM public.tournament_audit(
    v_t.id,
    'payment_submitted',
    p_participant_id,
    NULL,
    NULL,
    to_jsonb(v_s)
  );

  RETURN row_to_json(v_p);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_tournament_payment(uuid, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_tournament_payment(uuid, numeric, text, text) TO authenticated, service_role;

-- ============================================================================
-- 5. Session Control: start_booking_session & start_open_time_booking_session
-- ============================================================================
CREATE OR REPLACE FUNCTION public.start_booking_session(
  p_booking_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_shift_id uuid;
  v_now timestamptz := now();
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

  -- Idempotency: if already running, return success
  IF v_booking.status = 'in_progress'::public.booking_status THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'status', 'in_progress',
      'idempotent', true
    );
  END IF;

  IF v_booking.status NOT IN ('upcoming'::public.booking_status, 'pending'::public.booking_status) THEN
    RAISE EXCEPTION 'Booking is not startable from current status: %', v_booking.status
      USING ERRCODE = '55000';
  END IF;

  -- Require active shift for the lounge
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
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'NO_OPEN_SHIFT';
  END IF;

  -- Allow post-pay start for authorized staff; standard pre-booked requires payment
  IF COALESCE(v_booking.payment_status, 'unpaid') <> 'paid'
     AND COALESCE(v_booking.is_open_time, false) IS FALSE THEN
    -- If not open time and not paid, check if cashier is explicitly starting walk-in
    IF v_booking.payment_method <> 'cash' THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRED_BEFORE_SESSION_START' USING ERRCODE = '55000';
    END IF;
  END IF;

  UPDATE public.bookings AS b
  SET status = 'in_progress'::public.booking_status,
      checked_in_at = COALESCE(b.checked_in_at, v_now),
      actual_start_time = COALESCE(b.actual_start_time, v_now),
      shift_id = COALESCE(b.shift_id, v_shift_id),
      updated_at = v_now
  WHERE b.id = p_booking_id;

  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms AS r
    SET status = 'occupied',
        is_available = false,
        updated_at = v_now
    WHERE r.id = v_booking.room_id
      AND r.status NOT IN ('maintenance', 'deleted');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'status', 'in_progress',
    'shift_id', v_shift_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.start_booking_session(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_booking_session(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.start_open_time_booking_session(
  p_booking_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_shift_id uuid;
  v_now timestamptz := now();
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED' USING ERRCODE = '42501';
  END IF;

  SELECT l.*
  INTO v_lounge
  FROM public.lounges AS l
  WHERE l.id = v_booking.lounge_id
  FOR SHARE;

  IF NOT FOUND OR COALESCE(v_lounge.allow_open_time_sessions, false) IS FALSE THEN
    RAISE EXCEPTION 'OPEN_TIME_DISABLED_FOR_LOUNGE' USING ERRCODE = '55000';
  END IF;

  -- Require open shift
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
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'NO_OPEN_SHIFT';
  END IF;

  IF v_booking.status = 'in_progress'::public.booking_status THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'status', 'in_progress',
      'is_open_time', true,
      'idempotent', true
    );
  END IF;

  IF v_booking.status NOT IN ('upcoming'::public.booking_status, 'pending'::public.booking_status) THEN
    RAISE EXCEPTION 'BOOKING_NOT_STARTABLE' USING ERRCODE = '55000';
  END IF;

  -- Open Time walk-in sessions explicitly do NOT require prior payment
  UPDATE public.bookings AS b
  SET status = 'in_progress'::public.booking_status,
      is_open_time = true,
      checked_in_at = COALESCE(b.checked_in_at, v_now),
      actual_start_time = COALESCE(b.actual_start_time, v_now),
      open_time_started_at = COALESCE(b.open_time_started_at, v_now),
      shift_id = COALESCE(b.shift_id, v_shift_id),
      updated_at = v_now
  WHERE b.id = p_booking_id;

  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms AS r
    SET status = 'occupied',
        is_available = false,
        updated_at = v_now
    WHERE r.id = v_booking.room_id
      AND r.status NOT IN ('maintenance', 'deleted');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'status', 'in_progress',
    'is_open_time', true,
    'shift_id', v_shift_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.start_open_time_booking_session(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_open_time_booking_session(uuid) TO authenticated, service_role;

-- ============================================================================
-- 6. Session Completion: Idempotent complete_booking_session
-- ============================================================================
CREATE OR REPLACE FUNCTION public.complete_booking_session(
  p_booking_id uuid,
  p_action_by uuid DEFAULT NULL::uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_now timestamptz := now();
  v_start_time timestamptz;
  v_elapsed_minutes integer;
  v_billable_minutes integer;
  v_rounding integer := 15;
  v_minimum integer := 60;
  v_base_rate numeric;
  v_hourly_rate numeric;
  v_room_price numeric;
  v_total_price numeric;
  v_actor_id uuid := COALESCE(p_action_by, auth.uid());
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

  -- Idempotency check: if already completed, return final result without modification
  IF v_booking.status = 'completed'::public.booking_status THEN
    RETURN json_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'lounge_id', v_booking.lounge_id,
      'status', 'completed',
      'total_price', v_booking.total_price,
      'payment_status', v_booking.payment_status,
      'idempotent', true
    );
  END IF;

  IF v_booking.status <> 'in_progress'::public.booking_status THEN
    RAISE EXCEPTION 'Only in-progress sessions can be completed' USING ERRCODE = '55000';
  END IF;

  -- Calculate Open Time pricing if this is an open-time session
  IF COALESCE(v_booking.is_open_time, false) IS TRUE THEN
    SELECT l.* INTO v_lounge FROM public.lounges AS l WHERE l.id = v_booking.lounge_id;
    IF v_lounge.id IS NOT NULL THEN
      v_rounding := COALESCE(v_lounge.open_time_rounding_minutes, 15);
      v_minimum := COALESCE(v_lounge.open_time_minimum_minutes, 60);
    END IF;

    SELECT r.* INTO v_room FROM public.rooms AS r WHERE r.id = v_booking.room_id;

    v_start_time := COALESCE(v_booking.open_time_started_at, v_booking.actual_start_time, v_booking.created_at);
    v_elapsed_minutes := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_now - v_start_time)) / 60.0)::integer);

    -- Apply rounding and minimum
    v_billable_minutes := GREATEST(v_minimum, CEIL(v_elapsed_minutes::numeric / v_rounding::numeric)::integer * v_rounding);

    v_base_rate := CASE
      WHEN v_booking.play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0
        THEN v_room.hourly_rate_multi
      ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
    END;

    v_room_price := ROUND((v_base_rate / 60.0) * v_billable_minutes, 2);
    v_total_price := v_room_price + COALESCE(v_booking.addons_total, 0) - COALESCE(v_booking.discount_amount, 0);

    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
        open_time_closed_at = v_now,
        open_time_billing_minutes = v_billable_minutes,
        duration_minutes = v_billable_minutes,
        room_price = v_room_price,
        total_price = v_total_price,
        updated_at = v_now
    WHERE id = p_booking_id;
  ELSE
    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
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
    'total_price', COALESCE(v_total_price, v_booking.total_price),
    'payment_status', v_booking.payment_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_booking_session(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_session(uuid, uuid) TO authenticated, service_role;

-- ============================================================================
-- 7. Atomic Room Configuration: save_lounge_room
-- ============================================================================
CREATE OR REPLACE FUNCTION public.save_lounge_room(
  p_room_id uuid,
  p_lounge_id uuid,
  p_name text,
  p_category_id uuid DEFAULT NULL::uuid,
  p_single_price numeric DEFAULT 0,
  p_multi_price numeric DEFAULT 0,
  p_extra_controller_price numeric DEFAULT 0,
  p_activity_ids uuid[] DEFAULT ARRAY[]::uuid[],
  p_max_capacity integer DEFAULT 4,
  p_open_time_enabled boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_room_id uuid;
  v_activity_id uuid;
  v_existing_lounge_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Lounge ID is required' USING ERRCODE = '22023';
  END IF;

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Room name is required' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(p_lounge_id, 'rooms_manage') THEN
    RAISE EXCEPTION 'Not authorized to manage rooms in this lounge' USING ERRCODE = '42501';
  END IF;

  IF COALESCE(p_single_price, 0) < 0 OR COALESCE(p_multi_price, 0) < 0 OR COALESCE(p_extra_controller_price, 0) < 0 THEN
    RAISE EXCEPTION 'Prices must be non-negative' USING ERRCODE = '22023';
  END IF;

  IF COALESCE(p_max_capacity, 1) < 1 THEN
    RAISE EXCEPTION 'Max capacity must be at least 1' USING ERRCODE = '22023';
  END IF;

  -- Validate room does not belong to another lounge if updating
  IF p_room_id IS NOT NULL THEN
    SELECT r.lounge_id
    INTO v_existing_lounge_id
    FROM public.rooms AS r
    WHERE r.id = p_room_id;

    IF FOUND AND v_existing_lounge_id IS DISTINCT FROM p_lounge_id THEN
      RAISE EXCEPTION 'Cannot modify room belonging to another lounge' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Atomic Upsert of room
  INSERT INTO public.rooms (
    id,
    lounge_id,
    name,
    name_ar,
    hourly_rate_single,
    hourly_rate_multi,
    hourly_rate,
    extra_controller_price,
    max_capacity,
    is_available,
    status,
    updated_at
  ) VALUES (
    COALESCE(p_room_id, gen_random_uuid()),
    p_lounge_id,
    p_name,
    p_name,
    p_single_price,
    p_multi_price,
    p_single_price,
    p_extra_controller_price,
    p_max_capacity,
    true,
    'available',
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    name_ar = EXCLUDED.name_ar,
    hourly_rate_single = EXCLUDED.hourly_rate_single,
    hourly_rate_multi = EXCLUDED.hourly_rate_multi,
    hourly_rate = EXCLUDED.hourly_rate,
    extra_controller_price = EXCLUDED.extra_controller_price,
    max_capacity = EXCLUDED.max_capacity,
    updated_at = now()
  RETURNING id INTO v_room_id;

  -- Sync room activities atomically
  IF p_activity_ids IS NOT NULL THEN
    DELETE FROM public.room_activities WHERE room_id = v_room_id;

    IF cardinality(p_activity_ids) > 0 THEN
      FOREACH v_activity_id IN ARRAY p_activity_ids LOOP
        IF v_activity_id IS NOT NULL THEN
          INSERT INTO public.room_activities (room_id, activity_type_id)
          VALUES (v_room_id, v_activity_id)
          ON CONFLICT DO NOTHING;
        END IF;
      END LOOP;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'lounge_id', p_lounge_id,
    'name', p_name,
    'single_price', p_single_price,
    'multi_price', p_multi_price
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_lounge_room(uuid, uuid, text, uuid, numeric, numeric, numeric, uuid[], integer, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_lounge_room(uuid, uuid, text, uuid, numeric, numeric, numeric, uuid[], integer, boolean) TO authenticated, service_role;

COMMIT;
