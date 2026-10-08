-- Preserve hosted future-request policy, period conflicts and writer guard.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
CREATE OR REPLACE FUNCTION public.acquire_booking_hold(p_room_ids uuid[], p_start_at timestamp without time zone, p_end_at timestamp without time zone, p_hold_minutes integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_room_ids uuid[];
  v_room_id uuid;
  v_room_count integer;
  v_found_count integer;
  v_lounge_count integer;
  v_lounge_id uuid;
  v_lounge public.lounges%ROWTYPE;
  v_has_open_shift boolean;
  v_is_future boolean;
  v_tz text := 'Africa/Cairo';
  v_local_now timestamp without time zone;
  v_hold_token uuid := gen_random_uuid();
  v_expires_at timestamptz;
  v_is_request_only boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_start_at IS NULL OR p_end_at IS NULL OR p_end_at <= p_start_at THEN
    RAISE EXCEPTION 'Invalid booking hold range' USING ERRCODE = '22023';
  END IF;

  IF p_end_at - p_start_at > interval '24 hours' THEN
    RAISE EXCEPTION 'Booking hold range is too long' USING ERRCODE = '22023';
  END IF;

  IF p_room_ids IS NULL OR cardinality(p_room_ids) = 0 THEN
    RAISE EXCEPTION 'At least one room is required' USING ERRCODE = '22023';
  END IF;

  SELECT array_agg(room_id ORDER BY room_id), count(*)
  INTO v_room_ids, v_room_count
  FROM (
    SELECT DISTINCT unnest(p_room_ids) AS room_id
  ) AS requested_rooms;

  IF v_room_count > 20 THEN
    RAISE EXCEPTION 'Too many rooms requested' USING ERRCODE = '22023';
  END IF;

  -- Advisory lock on room IDs in deterministic order to prevent race conditions
  FOR v_room_id IN
    SELECT unnest(v_room_ids)
    ORDER BY 1
  LOOP
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_room_id::text, 0)
    );
  END LOOP;

  SELECT
    count(*),
    count(DISTINCT r.lounge_id),
    (array_agg(r.lounge_id ORDER BY r.lounge_id))[1]
  INTO v_found_count, v_lounge_count, v_lounge_id
  FROM public.rooms AS r
  WHERE r.id = ANY(v_room_ids)
    AND r.is_active IS TRUE
    -- Occupancy is temporal; administrative disablement still rejects.
    AND (r.is_available IS TRUE OR r.status = 'occupied')
    AND COALESCE(r.status, '') NOT IN ('maintenance', 'deleted');

  IF v_found_count <> v_room_count THEN
    RAISE EXCEPTION 'One or more rooms are unavailable' USING ERRCODE = '23514';
  END IF;

  IF v_lounge_count <> 1 THEN
    RAISE EXCEPTION 'All held rooms must belong to the same lounge' USING ERRCODE = '22023';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_lounge_id;

  IF COALESCE(v_lounge.is_active, false) IS FALSE THEN
    RAISE EXCEPTION 'Lounge is not active' USING ERRCODE = '55000';
  END IF;

  v_tz := COALESCE(NULLIF(btrim(v_lounge.timezone), ''), 'Africa/Cairo');
  v_local_now := now() AT TIME ZONE v_tz;

  -- Determine if this is a future request
  v_is_future := (p_start_at::date > v_local_now::date)
                 OR (p_start_at > (v_local_now + interval '2 hours'));

  SELECT EXISTS (
    SELECT 1 FROM public.shifts s
    WHERE s.lounge_id = v_lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
  ) INTO v_has_open_shift;

  -- Shift & Future booking policy evaluations
  IF NOT v_has_open_shift THEN
    IF NOT v_is_future THEN
      RAISE EXCEPTION 'Lounge currently has no active shift open for immediate walk-ins'
        USING ERRCODE = '55000';
    END IF;

    IF COALESCE(v_lounge.allow_future_bookings, true) IS FALSE THEN
      RAISE EXCEPTION 'Future bookings are disabled for this lounge' USING ERRCODE = '55000';
    END IF;

    IF COALESCE(v_lounge.allow_request_without_shift, true) IS FALSE THEN
      RAISE EXCEPTION 'Lounge does not accept requests while shifts are closed' USING ERRCODE = '55000';
    END IF;

    v_is_request_only := true;
  END IF;

  -- Check advance days limit
  IF v_is_future AND (p_start_at::date - v_local_now::date) > COALESCE(v_lounge.future_booking_max_days_advance, 14) THEN
    RAISE EXCEPTION 'Requested date exceeds lounge advance booking limit of % days',
      v_lounge.future_booking_max_days_advance USING ERRCODE = '22023';
  END IF;

  -- Check operating hours against operational day
  IF v_lounge.opening_time IS NOT NULL AND v_lounge.closing_time IS NOT NULL THEN
    IF v_lounge.closing_time <= v_lounge.opening_time THEN
      -- Overnight hours: valid if after opening or before closing
      IF NOT (p_start_at::time >= v_lounge.opening_time OR p_start_at::time < v_lounge.closing_time) THEN
        RAISE EXCEPTION 'Selected range is outside lounge working hours' USING ERRCODE = '22023';
      END IF;
    ELSE
      IF p_start_at::time < v_lounge.opening_time OR p_end_at::time > v_lounge.closing_time THEN
        RAISE EXCEPTION 'Selected range is outside lounge working hours' USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  -- Release existing user holds
  UPDATE public.booking_holds
  SET released_at = now()
  WHERE user_id = v_user_id
    AND released_at IS NULL
    AND expires_at > now();

  -- Conflict check against existing confirmed bookings
  IF EXISTS (
    SELECT 1
    FROM public.bookings AS b
    WHERE b.room_id = ANY(v_room_ids)
      AND b.booking_period IS NOT NULL
      AND b.status IN ('upcoming'::public.booking_status, 'in_progress'::public.booking_status)
      AND b.confirmation_status = 'confirmed'
      AND b.booking_period && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_OVERLAP_CONFLICT',
      'message', 'Slot is already booked'
    );
  END IF;

  -- Conflict check against other user active holds
  IF EXISTS (
    SELECT 1
    FROM public.booking_holds AS h
    WHERE h.room_id = ANY(v_room_ids)
      AND h.user_id IS DISTINCT FROM v_user_id
      AND h.released_at IS NULL
      AND h.expires_at > now()
      AND pg_catalog.tsrange(h.start_at, h.end_at, '[)') && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_HELD_BY_ANOTHER_USER',
      'message', 'Slot is temporarily held by another customer'
    );
  END IF;

  v_expires_at := now() + make_interval(mins => LEAST(GREATEST(p_hold_minutes, 3), 30));

  INSERT INTO public.booking_holds (
    hold_token, user_id, lounge_id, room_id, start_at, end_at, expires_at
  )
  SELECT
    v_hold_token, v_user_id, v_lounge_id, room_id, p_start_at, p_end_at, v_expires_at
  FROM unnest(v_room_ids) AS room_id;

  RETURN jsonb_build_object(
    'success', true,
    'hold_token', v_hold_token,
    'lounge_id', v_lounge_id,
    'room_ids', v_room_ids,
    'start_at', p_start_at,
    'end_at', p_end_at,
    'expires_at', v_expires_at,
    'is_request_only', v_is_request_only,
    'has_open_shift', v_has_open_shift
  );
END;
$function$;

COMMIT;
