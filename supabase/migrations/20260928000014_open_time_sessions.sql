BEGIN;

ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS open_time_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS open_time_pricing_mode text NOT NULL DEFAULT 'same_hourly',
  ADD COLUMN IF NOT EXISTS open_time_custom_hourly_rate numeric(10,2),
  ADD COLUMN IF NOT EXISTS open_time_price_multiplier numeric(8,4) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS open_time_minimum_minutes integer NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS open_time_rounding_minutes integer NOT NULL DEFAULT 15,
  ADD COLUMN IF NOT EXISTS open_time_max_minutes integer,
  ADD COLUMN IF NOT EXISTS open_time_buffer_before_booking_minutes integer NOT NULL DEFAULT 15;

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS is_open_time boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS open_time_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS open_time_ended_at timestamptz,
  ADD COLUMN IF NOT EXISTS open_time_pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;

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

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'rooms_open_time_values_check'
      AND conrelid = 'public.rooms'::regclass
  ) THEN
    ALTER TABLE public.rooms
      ADD CONSTRAINT rooms_open_time_values_check
      CHECK (
        open_time_price_multiplier >= 1
        AND open_time_minimum_minutes BETWEEN 1 AND 1440
        AND open_time_rounding_minutes BETWEEN 1 AND 240
        AND (open_time_max_minutes IS NULL OR open_time_max_minutes BETWEEN 1 AND 1440)
        AND open_time_buffer_before_booking_minutes BETWEEN 0 AND 240
        AND (open_time_custom_hourly_rate IS NULL OR open_time_custom_hourly_rate >= 0)
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bookings_open_time_active
ON public.bookings (room_id, status, is_open_time)
WHERE is_open_time IS TRUE
  AND status = 'in_progress'::public.booking_status;

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
AS $function$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_shift_id uuid;
  v_booking_id uuid;
  v_started_at timestamptz := now();
  v_local_started_at timestamp without time zone := now() AT TIME ZONE 'Africa/Cairo';
  v_next_booking_start timestamp without time zone;
  v_must_end_by timestamp without time zone;
  v_play_mode text := lower(COALESCE(NULLIF(btrim(p_play_mode), ''), 'single'));
  v_base_rate numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF v_play_mode NOT IN ('single', 'multi') THEN
    RAISE EXCEPTION 'Invalid play mode' USING ERRCODE = '22023';
  END IF;

  SELECT r.*
  INTO v_room
  FROM public.rooms AS r
  WHERE r.id = p_room_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = '22023';
  END IF;

  IF NOT private.can_operate_playspot_lounge(v_room.lounge_id) THEN
    RAISE EXCEPTION 'Not authorized for this lounge' USING ERRCODE = '42501';
  END IF;

  IF COALESCE(v_room.open_time_enabled, false) IS FALSE THEN
    RAISE EXCEPTION 'OPEN_TIME_DISABLED' USING ERRCODE = '55000';
  END IF;

  IF COALESCE(v_room.status::text, 'available') = 'maintenance'
     OR COALESCE(v_room.is_available, true) IS FALSE THEN
    RAISE EXCEPTION 'Room is not available' USING ERRCODE = '55000';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.bookings AS b
    WHERE b.room_id = p_room_id
      AND b.status = 'in_progress'::public.booking_status
  ) THEN
    RAISE EXCEPTION 'Room already has an active session' USING ERRCODE = '55000';
  END IF;

  SELECT min(b.date::date + b.start_time::time)
  INTO v_next_booking_start
  FROM public.bookings AS b
  WHERE b.room_id = p_room_id
    AND b.status IN (
      'pending'::public.booking_status,
      'upcoming'::public.booking_status
    )
    AND (b.date::date + b.start_time::time) > v_local_started_at;

  IF v_next_booking_start IS NOT NULL THEN
    v_must_end_by :=
      v_next_booking_start
      - make_interval(mins => COALESCE(v_room.open_time_buffer_before_booking_minutes, 15));

    IF v_must_end_by <= v_local_started_at THEN
      RAISE EXCEPTION 'NEXT_BOOKING_TOO_SOON' USING ERRCODE = '55000';
    END IF;
  END IF;

  SELECT s.id
  INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.lounge_id = v_room.lounge_id
    AND s.status IN ('open', 'active')
  ORDER BY s.created_at DESC, s.id DESC
  LIMIT 1;

  IF v_shift_id IS NULL THEN
    RAISE EXCEPTION 'No active shift for this lounge' USING ERRCODE = '55000';
  END IF;

  v_base_rate := CASE
    WHEN v_play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0
      THEN v_room.hourly_rate_multi
    ELSE v_room.hourly_rate_single
  END;

  IF COALESCE(v_base_rate, 0) <= 0 THEN
    RAISE EXCEPTION 'Room has no valid hourly rate' USING ERRCODE = '23514';
  END IF;

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
    open_time_pricing_snapshot,
    created_at,
    updated_at
  )
  VALUES (
    v_room.lounge_id,
    v_room.id,
    COALESCE(NULLIF(v_room.name_ar, ''), NULLIF(v_room.name_en, ''), v_room.name),
    COALESCE(NULLIF(btrim(p_customer_name), ''), 'Walk-in customer'),
    NULLIF(btrim(p_customer_phone), ''),
    v_local_started_at::date,
    to_char(v_local_started_at, 'HH24:MI:SS'),
    to_char(v_local_started_at, 'HH24:MI:SS'),
    0,
    'in_progress'::public.booking_status,
    'paid',
    'cash',
    v_shift_id,
    v_play_mode,
    0,
    0,
    true,
    v_started_at,
    jsonb_build_object(
      'pricing_mode', v_room.open_time_pricing_mode,
      'base_hourly_rate', v_base_rate,
      'custom_hourly_rate', v_room.open_time_custom_hourly_rate,
      'price_multiplier', v_room.open_time_price_multiplier,
      'minimum_minutes', v_room.open_time_minimum_minutes,
      'rounding_minutes', v_room.open_time_rounding_minutes,
      'max_minutes', v_room.open_time_max_minutes,
      'buffer_before_booking_minutes', v_room.open_time_buffer_before_booking_minutes,
      'must_end_by', v_must_end_by
    ),
    now(),
    now()
  )
  RETURNING id INTO v_booking_id;

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
    'must_end_by', v_must_end_by
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_open_time_session(
  p_booking_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_ended_at timestamptz := now();
  v_elapsed_minutes integer;
  v_billable_minutes integer;
  v_rounding integer;
  v_minimum integer;
  v_base_rate numeric;
  v_hourly_rate numeric;
  v_room_total numeric;
  v_extras_total numeric := 0;
  v_final_total numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
    AND b.is_open_time IS TRUE
    AND b.status = 'in_progress'::public.booking_status
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active open time session not found' USING ERRCODE = '22023';
  END IF;

  IF NOT private.can_operate_playspot_lounge(v_booking.lounge_id) THEN
    RAISE EXCEPTION 'Not authorized for this lounge' USING ERRCODE = '42501';
  END IF;

  SELECT r.*
  INTO v_room
  FROM public.rooms AS r
  WHERE r.id = v_booking.room_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = '22023';
  END IF;

  v_elapsed_minutes :=
    GREATEST(1, CEIL(EXTRACT(EPOCH FROM (v_ended_at - v_booking.open_time_started_at)) / 60.0)::integer);
  v_rounding := GREATEST(1, COALESCE(v_room.open_time_rounding_minutes, 15));
  v_minimum := GREATEST(1, COALESCE(v_room.open_time_minimum_minutes, 30));
  v_billable_minutes :=
    GREATEST(v_minimum, CEIL(v_elapsed_minutes::numeric / v_rounding::numeric)::integer * v_rounding);

  IF v_room.open_time_max_minutes IS NOT NULL
     AND v_elapsed_minutes > v_room.open_time_max_minutes THEN
    RAISE EXCEPTION 'OPEN_TIME_MAX_EXCEEDED' USING ERRCODE = '55000';
  END IF;

  v_base_rate := COALESCE(
    NULLIF((v_booking.open_time_pricing_snapshot->>'base_hourly_rate')::numeric, 0),
    CASE
      WHEN v_booking.play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0
        THEN v_room.hourly_rate_multi
      ELSE v_room.hourly_rate_single
    END
  );

  v_hourly_rate := CASE COALESCE(v_room.open_time_pricing_mode, 'same_hourly')
    WHEN 'custom_hourly' THEN COALESCE(v_room.open_time_custom_hourly_rate, v_base_rate)
    WHEN 'hourly_plus_percentage' THEN v_base_rate * COALESCE(v_room.open_time_price_multiplier, 1)
    ELSE v_base_rate
  END;

  IF COALESCE(v_hourly_rate, 0) <= 0 THEN
    RAISE EXCEPTION 'Room has no valid open time rate' USING ERRCODE = '23514';
  END IF;

  SELECT COALESCE(sum(COALESCE(bi.total_price, bi.unit_price * bi.quantity, 0)), 0)
  INTO v_extras_total
  FROM public.booking_items AS bi
  WHERE bi.booking_id = p_booking_id;

  v_room_total := ROUND((v_hourly_rate * v_billable_minutes::numeric / 60.0), 2);
  v_final_total := ROUND(v_room_total + COALESCE(v_extras_total, 0), 2);

  UPDATE public.bookings
  SET status = 'completed'::public.booking_status,
      open_time_ended_at = v_ended_at,
      duration_minutes = v_billable_minutes,
      end_time = to_char(v_ended_at AT TIME ZONE 'Africa/Cairo', 'HH24:MI:SS'),
      room_price = v_room_total,
      total_price = v_final_total,
      payment_status = 'paid',
      open_time_pricing_snapshot = COALESCE(open_time_pricing_snapshot, '{}'::jsonb)
        || jsonb_build_object(
          'ended_at', v_ended_at,
          'elapsed_minutes', v_elapsed_minutes,
          'billable_minutes', v_billable_minutes,
          'hourly_rate', v_hourly_rate,
          'room_total', v_room_total,
          'extras_total', v_extras_total,
          'final_total', v_final_total
        ),
      updated_at = now()
  WHERE id = p_booking_id;

  UPDATE public.rooms
  SET status = 'available',
      is_available = true,
      updated_at = now()
  WHERE id = v_booking.room_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'elapsed_minutes', v_elapsed_minutes,
    'billable_minutes', v_billable_minutes,
    'room_total', v_room_total,
    'extras_total', v_extras_total,
    'final_total', v_final_total
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.start_open_time_session(uuid, text, text, text)
FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_open_time_session(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.start_open_time_session(uuid, text, text, text)
TO authenticated, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.complete_open_time_session(uuid)
TO authenticated, service_role, supabase_auth_admin;

COMMIT;
