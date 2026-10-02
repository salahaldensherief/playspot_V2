BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ============================================================================
-- 1. Ensure Open Time Configuration Columns on Rooms Table
-- ============================================================================
ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS open_time_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS open_time_pricing_mode text NOT NULL DEFAULT 'same_hourly',
  ADD COLUMN IF NOT EXISTS open_time_custom_hourly_rate numeric(10,2),
  ADD COLUMN IF NOT EXISTS open_time_price_multiplier numeric(8,4) NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS open_time_minimum_minutes integer NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS open_time_rounding_minutes integer NOT NULL DEFAULT 15,
  ADD COLUMN IF NOT EXISTS open_time_max_minutes integer DEFAULT 720,
  ADD COLUMN IF NOT EXISTS open_time_buffer_before_booking_minutes integer NOT NULL DEFAULT 15;

-- Ensure Open Time pricing mode constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'rooms_open_time_pricing_mode_check'
      AND conrelid = 'public.rooms'::regclass
  ) THEN
    ALTER TABLE public.rooms
      ADD CONSTRAINT rooms_open_time_pricing_mode_check
      CHECK (open_time_pricing_mode IN ('same_hourly', 'custom_hourly', 'hourly_plus_percentage'));
  END IF;
END $$;

-- Ensure Open Time Snapshot Column on Bookings Table
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS open_time_pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Index for fast lookup of active open time sessions
CREATE INDEX IF NOT EXISTS idx_bookings_open_time_active
ON public.bookings (room_id, status, is_open_time)
WHERE is_open_time IS TRUE
  AND status = 'in_progress'::public.booking_status;

-- ============================================================================
-- 2. Update fn_validate_and_clamp_booking_price Trigger Function
--    Fix: Allow Open Time duration starting at 0/1 without throwing,
--         and preserve open_time_pricing_snapshot during updates.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_validate_and_clamp_booking_price()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actual_hourly_rate numeric := 0;
  v_extra_controller_rate numeric := 0;
  v_addons numeric := 0;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_snap jsonb;
BEGIN
  -- If this is an Open Time session in progress, do not clamp or fail on duration
  IF COALESCE(NEW.is_open_time, false) IS TRUE AND NEW.status = 'in_progress'::public.booking_status THEN
    NEW.duration_minutes := GREATEST(1, COALESCE(NEW.duration_minutes, 1));
    RETURN NEW;
  END IF;

  -- For standard bookings or completed sessions, validate duration
  IF COALESCE(NEW.duration_minutes, 0) <= 0 OR NEW.duration_minutes > 1440 THEN
    RAISE EXCEPTION 'Invalid booking duration: % minutes. Duration must be between 1 and 1440 minutes.',
      NEW.duration_minutes USING ERRCODE = '22023';
  END IF;

  IF NEW.room_id IS NULL THEN
    RAISE EXCEPTION 'Cannot validate booking price: room_id is required.' USING ERRCODE = '22023';
  END IF;

  -- If an Open Time session is completed with a pricing snapshot, honor the snapshot!
  IF COALESCE(NEW.is_open_time, false) IS TRUE AND NEW.open_time_pricing_snapshot IS NOT NULL AND NEW.open_time_pricing_snapshot <> '{}'::jsonb THEN
    v_snap := NEW.open_time_pricing_snapshot;
    v_actual_hourly_rate := COALESCE((v_snap->>'effective_hourly_rate')::numeric, (v_snap->>'base_hourly_rate')::numeric, 50);
  ELSE
    SELECT
      COALESCE(
        CASE
          WHEN NEW.play_mode = 'multi' AND COALESCE(r.hourly_rate_multi, 0) > 0 THEN r.hourly_rate_multi
          ELSE r.hourly_rate_single
        END,
        0
      ),
      GREATEST(0, COALESCE(NEW.extra_controllers, 0)) * COALESCE(r.extra_controller_price, 0)
    INTO
      v_actual_hourly_rate,
      v_extra_controller_rate
    FROM public.rooms r
    WHERE r.id = NEW.room_id;

    IF v_actual_hourly_rate <= 0 THEN
      RAISE EXCEPTION 'Cannot validate booking price: room % has no valid rate configured.', NEW.room_id
        USING ERRCODE = '23514';
    END IF;
  END IF;

  -- Compute room price
  IF COALESCE(NEW.is_open_time, false) IS FALSE OR NEW.status = 'completed'::public.booking_status THEN
    NEW.room_price := ROUND((NEW.duration_minutes / 60.0) * (v_actual_hourly_rate + v_extra_controller_rate), 2);
  END IF;

  v_addons := GREATEST(0, COALESCE(NEW.addons_price, NEW.addons_total, 0));
  NEW.addons_price := v_addons;
  NEW.addons_total := v_addons;

  v_subtotal := NEW.room_price + v_addons;

  IF COALESCE(NEW.discount_amount, 0) > 0 THEN
    v_discount := LEAST(v_subtotal, NEW.discount_amount);
  ELSIF COALESCE(NEW.discount_percentage, 0) > 0 THEN
    v_discount := LEAST(v_subtotal, v_subtotal * (NEW.discount_percentage / 100.0));
  ELSE
    v_discount := 0;
  END IF;

  NEW.discount_amount := v_discount;
  NEW.total_price := GREATEST(0, v_subtotal - v_discount);

  RETURN NEW;
END;
$$;

-- ============================================================================
-- 3. Canonical start_open_time_session RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION public.start_open_time_session(
  p_room_id uuid,
  p_customer_name text DEFAULT NULL::text,
  p_customer_phone text DEFAULT NULL::text,
  p_play_mode text DEFAULT 'single'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_shift_id uuid;
  v_booking_id uuid;
  v_started_at timestamptz := now();
  v_tz text := 'Africa/Cairo';
  v_local_now timestamp without time zone;
  v_next_booking_start timestamp without time zone;
  v_must_end_by timestamp without time zone;
  v_play_mode text := lower(COALESCE(NULLIF(btrim(p_play_mode), ''), 'single'));
  v_base_rate numeric;
  v_effective_rate numeric;
  v_snapshot jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF v_play_mode NOT IN ('single', 'multi') THEN
    RAISE EXCEPTION 'Invalid play mode: %', p_play_mode USING ERRCODE = '22023';
  END IF;

  SELECT r.*
  INTO v_room
  FROM public.rooms AS r
  WHERE r.id = p_room_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT l.*
  INTO v_lounge
  FROM public.lounges AS l
  WHERE l.id = v_room.lounge_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lounge not found' USING ERRCODE = 'P0002';
  END IF;

  v_tz := COALESCE(NULLIF(btrim(v_lounge.timezone), ''), 'Africa/Cairo');
  v_local_now := v_started_at AT TIME ZONE v_tz;

  -- Permission check
  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_room.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'Not authorized for session control in this lounge' USING ERRCODE = '42501';
  END IF;

  -- Policy checks
  IF COALESCE(v_lounge.allow_open_time_sessions, false) IS FALSE THEN
    RAISE EXCEPTION 'Open time sessions are disabled for this lounge' USING ERRCODE = '55000';
  END IF;

  IF COALESCE(v_room.open_time_enabled, true) IS FALSE THEN
    RAISE EXCEPTION 'Open time sessions are disabled for this room' USING ERRCODE = '55000';
  END IF;

  IF COALESCE(v_room.status, 'available') = 'maintenance'
     OR COALESCE(v_room.is_available, true) IS FALSE THEN
    RAISE EXCEPTION 'Room is not available' USING ERRCODE = '55000';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bookings AS b
    WHERE b.room_id = p_room_id AND b.status = 'in_progress'::public.booking_status
  ) THEN
    RAISE EXCEPTION 'Room already has an active session' USING ERRCODE = '55000';
  END IF;

  -- Require open shift of this lounge
  SELECT s.id
  INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.lounge_id = v_room.lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
  ORDER BY s.opened_at DESC
  LIMIT 1
  FOR SHARE;

  IF v_shift_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'NO_OPEN_SHIFT';
  END IF;

  -- Protection of upcoming bookings & must_end_by calculation
  SELECT min(b.date::date + b.start_time::time)
  INTO v_next_booking_start
  FROM public.bookings AS b
  WHERE b.room_id = p_room_id
    AND b.status IN ('pending'::public.booking_status, 'upcoming'::public.booking_status)
    AND (b.date::date + b.start_time::time) > v_local_now;

  IF v_next_booking_start IS NOT NULL THEN
    v_must_end_by := v_next_booking_start - make_interval(mins => COALESCE(v_room.open_time_buffer_before_booking_minutes, 15));
    IF v_must_end_by <= v_local_now THEN
      RAISE EXCEPTION 'Next booking is too soon to start an open time session' USING ERRCODE = '55000';
    END IF;
  END IF;

  -- Rate determination
  v_base_rate := CASE
    WHEN v_play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN v_room.hourly_rate_multi
    ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
  END;

  IF COALESCE(v_base_rate, 0) <= 0 THEN
    RAISE EXCEPTION 'Room has no valid hourly rate configured' USING ERRCODE = '23514';
  END IF;

  v_effective_rate := CASE v_room.open_time_pricing_mode
    WHEN 'custom_hourly' THEN COALESCE(v_room.open_time_custom_hourly_rate, v_base_rate)
    WHEN 'hourly_plus_percentage' THEN ROUND(v_base_rate * COALESCE(v_room.open_time_price_multiplier, 1.0), 2)
    ELSE v_base_rate
  END;

  -- Build price & policy snapshot
  v_snapshot := jsonb_build_object(
    'pricing_mode', COALESCE(v_room.open_time_pricing_mode, 'same_hourly'),
    'base_hourly_rate', v_base_rate,
    'effective_hourly_rate', v_effective_rate,
    'custom_hourly_rate', v_room.open_time_custom_hourly_rate,
    'price_multiplier', v_room.open_time_price_multiplier,
    'minimum_minutes', COALESCE(v_room.open_time_minimum_minutes, v_lounge.open_time_minimum_minutes, 30),
    'rounding_minutes', COALESCE(v_room.open_time_rounding_minutes, v_lounge.open_time_rounding_minutes, 15),
    'max_minutes', COALESCE(v_room.open_time_max_minutes, v_lounge.open_time_max_minutes, 720),
    'buffer_before_booking_minutes', COALESCE(v_room.open_time_buffer_before_booking_minutes, 15),
    'must_end_by', v_must_end_by
  );

  -- Insert Open Time booking (payment_status = 'unpaid', no fake collection!)
  INSERT INTO public.bookings (
    lounge_id,
    room_id,
    room_name,
    user_name,
    user_phone,
    date,
    start_time,
    end_time,
    duration_minutes,
    status,
    payment_status,
    payment_method,
    shift_id,
    play_mode,
    room_price,
    total_price,
    is_open_time,
    open_time_started_at,
    checked_in_at,
    actual_start_time,
    open_time_pricing_snapshot,
    created_at,
    updated_at
  ) VALUES (
    v_room.lounge_id,
    v_room.id,
    COALESCE(NULLIF(v_room.name_ar, ''), NULLIF(v_room.name_en, ''), v_room.name),
    COALESCE(NULLIF(btrim(p_customer_name), ''), 'Walk-in customer'),
    NULLIF(btrim(p_customer_phone), ''),
    v_local_now::date,
    to_char(v_local_now, 'HH24:MI:SS')::time,
    to_char(v_local_now, 'HH24:MI:SS')::time,
    1,
    'in_progress'::public.booking_status,
    'unpaid',
    'cash',
    v_shift_id,
    v_play_mode,
    0,
    0,
    true,
    v_started_at,
    v_started_at,
    v_started_at,
    v_snapshot,
    now(),
    now()
  )
  RETURNING id INTO v_booking_id;

  -- Occupy room
  UPDATE public.rooms
  SET status = 'occupied',
      is_available = false,
      updated_at = now()
  WHERE id = v_room.id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'room_id', v_room.id,
    'lounge_id', v_room.lounge_id,
    'started_at', v_started_at,
    'must_end_by', v_must_end_by,
    'status', 'in_progress',
    'is_open_time', true,
    'shift_id', v_shift_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.start_open_time_session(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_open_time_session(uuid, text, text, text) TO authenticated, service_role;

-- ============================================================================
-- 4. Complete Open Time Session: Enhanced complete_booking_session
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

  -- Idempotency: if already completed, return existing totals without recalculating
  IF v_booking.status = 'completed'::public.booking_status THEN
    v_amount_paid := CASE WHEN v_booking.payment_status = 'paid' THEN v_booking.total_price ELSE 0 END;
    v_amount_due := GREATEST(0, v_booking.total_price - v_amount_paid);

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

  -- If this is an Open Time session, calculate billing from snapshot
  IF COALESCE(v_booking.is_open_time, false) IS TRUE THEN
    v_snap := v_booking.open_time_pricing_snapshot;

    IF v_snap IS NOT NULL AND v_snap <> '{}'::jsonb THEN
      v_rate := COALESCE((v_snap->>'effective_hourly_rate')::numeric, (v_snap->>'base_hourly_rate')::numeric, 50);
      v_minimum := COALESCE((v_snap->>'minimum_minutes')::integer, 30);
      v_rounding := COALESCE((v_snap->>'rounding_minutes')::integer, 15);
      v_max := COALESCE((v_snap->>'max_minutes')::integer, 720);
    ELSE
      -- Fallback to lounge & room current settings
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

    -- Apply max cap as billing ceiling
    IF v_max IS NOT NULL AND v_max > 0 THEN
      v_billable_raw := LEAST(v_elapsed_minutes, v_max);
    ELSE
      v_billable_raw := v_elapsed_minutes;
    END IF;

    -- Apply minimum minutes
    v_billable_raw := GREATEST(v_billable_raw, v_minimum);

    -- Apply rounding
    v_billable_minutes := CEIL(v_billable_raw::numeric / v_rounding::numeric)::integer * v_rounding;

    v_room_price := ROUND((v_rate / 60.0) * v_billable_minutes, 2);
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
    -- Standard pre-booked session completion
    v_total_price := v_booking.total_price;
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

  v_amount_paid := CASE WHEN v_booking.payment_status = 'paid' THEN v_total_price ELSE 0 END;
  v_amount_due := GREATEST(0, v_total_price - v_amount_paid);

  RETURN json_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'lounge_id', v_booking.lounge_id,
    'status', 'completed',
    'final_total', v_total_price,
    'amount_paid', v_amount_paid,
    'amount_due', v_amount_due,
    'payment_status', v_booking.payment_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_booking_session(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_session(uuid, uuid) TO authenticated, service_role;

-- ============================================================================
-- 5. Client Availability & Unified Pricing Engine RPCs
-- ============================================================================

-- ----------------------------------------------------------------------------
-- quote_booking_price
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.quote_booking_price(
  p_room_id uuid,
  p_date date,
  p_start time without time zone,
  p_end time without time zone,
  p_play_mode text DEFAULT 'single'::text,
  p_extra_controllers integer DEFAULT 0,
  p_coupon_code text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_start_min integer;
  v_end_min integer;
  v_duration_min integer;
  v_base_rate numeric;
  v_controller_rate numeric := 0;
  v_controllers_amount numeric := 0;
  v_room_subtotal numeric := 0;
  v_promo_discount numeric := 0;
  v_final_total numeric := 0;
  v_play_mode text := lower(COALESCE(NULLIF(btrim(p_play_mode), ''), 'single'));
  v_currency text := 'EGP';
BEGIN
  IF p_room_id IS NULL OR p_date IS NULL OR p_start IS NULL OR p_end IS NULL THEN
    RAISE EXCEPTION 'Missing required arguments for price quote' USING ERRCODE = '22023';
  END IF;

  SELECT r.* INTO v_room FROM public.rooms r WHERE r.id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_room.lounge_id;

  v_start_min := (EXTRACT(HOUR FROM p_start) * 60 + EXTRACT(MINUTE FROM p_start))::integer;
  v_end_min := (EXTRACT(HOUR FROM p_end) * 60 + EXTRACT(MINUTE FROM p_end))::integer;

  -- Handle midnight crossing
  IF v_end_min <= v_start_min THEN
    v_end_min := v_end_min + 1440;
  END IF;

  v_duration_min := v_end_min - v_start_min;
  IF v_duration_min <= 0 OR v_duration_min > 1440 THEN
    RAISE EXCEPTION 'Invalid booking duration' USING ERRCODE = '22023';
  END IF;

  v_base_rate := CASE
    WHEN v_play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN v_room.hourly_rate_multi
    ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
  END;

  v_room_subtotal := ROUND((v_base_rate / 60.0) * v_duration_min, 2);

  -- Extra controllers
  IF COALESCE(p_extra_controllers, 0) > 0 THEN
    v_controller_rate := COALESCE(v_room.extra_controller_price, 0);
    v_controllers_amount := ROUND((p_extra_controllers * v_controller_rate * (v_duration_min / 60.0)), 2);
  END IF;

  -- Coupon check
  IF p_coupon_code IS NOT NULL AND btrim(p_coupon_code) <> '' THEN
    SELECT
      CASE
        WHEN p.discount_type = 'percentage' THEN ROUND((v_room_subtotal * (p.discount_value / 100.0)), 2)
        WHEN p.discount_type = 'fixed' THEN LEAST(v_room_subtotal, p.discount_value)
        ELSE 0
      END
    INTO v_promo_discount
    FROM public.promotions p
    WHERE p.is_active = true
      AND (p.room_id IS NULL OR p.room_id = p_room_id)
      AND lower(btrim(p.code)) = lower(btrim(p_coupon_code))
      AND (p.expires_at IS NULL OR p.expires_at > now())
    LIMIT 1;

    v_promo_discount := COALESCE(v_promo_discount, 0);
  END IF;

  v_final_total := GREATEST(0, (v_room_subtotal + v_controllers_amount) - v_promo_discount);

  RETURN jsonb_build_object(
    'room_id', p_room_id,
    'lounge_id', v_room.lounge_id,
    'date', p_date,
    'start_time', to_char(p_start, 'HH24:MI:SS'),
    'end_time', to_char(p_end, 'HH24:MI:SS'),
    'duration_minutes', v_duration_min,
    'play_mode', v_play_mode,
    'base_rate', v_base_rate,
    'room_subtotal', v_room_subtotal,
    'extra_controllers', COALESCE(p_extra_controllers, 0),
    'controllers_amount', v_controllers_amount,
    'addons_amount', 0,
    'discount_amount', v_promo_discount,
    'subtotal', v_room_subtotal + v_controllers_amount,
    'final_total', v_final_total,
    'currency', v_currency,
    'has_peak_rates', false,
    'segments', jsonb_build_array(
      jsonb_build_object(
        'from', to_char(p_start, 'HH24:MI:SS'),
        'to', to_char(p_end, 'HH24:MI:SS'),
        'minutes', v_duration_min,
        'rate', v_base_rate,
        'amount', v_room_subtotal
      )
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.quote_booking_price(uuid, date, time, time, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_booking_price(uuid, date, time, time, text, integer, text) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- get_room_slots_with_prices
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_room_slots_with_prices(
  p_room_id uuid,
  p_date date
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_slots jsonb := '[]'::jsonb;
  v_slot_start time without time zone;
  v_slot_end time without time zone;
  v_cur_min integer;
  v_open_min integer;
  v_close_min integer;
  v_is_available boolean;
  v_quote jsonb;
BEGIN
  SELECT r.* INTO v_room FROM public.rooms r WHERE r.id = p_room_id;
  IF NOT FOUND THEN
    RETURN json_build_array();
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_room.lounge_id;

  v_open_min := (EXTRACT(HOUR FROM COALESCE(v_lounge.opening_time, '10:00:00'::time)) * 60)::integer;
  v_close_min := (EXTRACT(HOUR FROM COALESCE(v_lounge.closing_time, '23:00:00'::time)) * 60)::integer;

  IF v_close_min <= v_open_min THEN
    v_close_min := v_close_min + 1440;
  END IF;

  v_cur_min := v_open_min;

  WHILE v_cur_min + 60 <= v_close_min LOOP
    v_slot_start := ('00:00:00'::time + ((v_cur_min % 1440) || ' minutes')::interval);
    v_slot_end := ('00:00:00'::time + (((v_cur_min + 60) % 1440) || ' minutes')::interval);

    -- Check if slot overlaps with existing booking
    v_is_available := NOT EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.room_id = p_room_id
        AND b.date = p_date
        AND b.status IN ('upcoming'::public.booking_status, 'in_progress'::public.booking_status)
        AND (b.start_time, b.end_time) OVERLAPS (v_slot_start, v_slot_end)
    );

    v_quote := public.quote_booking_price(
      p_room_id => p_room_id,
      p_date => p_date,
      p_start => v_slot_start,
      p_end => v_slot_end
    );

    v_slots := v_slots || jsonb_build_object(
      'start_time', to_char(v_slot_start, 'HH24:MI:SS'),
      'end_time', to_char(v_slot_end, 'HH24:MI:SS'),
      'is_available', v_is_available,
      'price', (v_quote->>'final_total')::numeric
    );

    v_cur_min := v_cur_min + 60;
  END LOOP;

  RETURN jsonb_build_array(v_slots);
END;
$$;

REVOKE ALL ON FUNCTION public.get_room_slots_with_prices(uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_room_slots_with_prices(uuid, date) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- get_lounge_price_range
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_lounge_price_range(
  p_lounge_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_min numeric;
  v_max numeric;
BEGIN
  SELECT
    MIN(COALESCE(r.hourly_rate_single, r.hourly_rate, 0)),
    MAX(GREATEST(COALESCE(r.hourly_rate_multi, 0), COALESCE(r.hourly_rate_single, r.hourly_rate, 0)))
  INTO v_min, v_max
  FROM public.rooms r
  WHERE r.lounge_id = p_lounge_id
    AND COALESCE(r.status, 'available') <> 'deleted'
    AND COALESCE(r.is_active, true) IS TRUE;

  RETURN jsonb_build_object(
    'lounge_id', p_lounge_id,
    'min_price', COALESCE(v_min, 0),
    'max_price', COALESCE(v_max, 0),
    'currency', 'EGP'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_lounge_price_range(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lounge_price_range(uuid) TO authenticated, service_role;

COMMIT;
