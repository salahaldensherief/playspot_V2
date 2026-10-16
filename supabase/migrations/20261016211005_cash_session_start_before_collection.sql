BEGIN;

-- Separate cash attendance from collection without writing payment or ledger rows.
-- Existing permissions, open-shift checks, locks and grants are retained.
CREATE OR REPLACE FUNCTION public.start_booking_session(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  -- Starting a cash session records attendance, never collection. Unverified
  -- prepaid methods remain blocked; refunded bookings cannot restart play.
  IF COALESCE(v_booking.payment_status, 'unpaid') = 'refunded'
     OR (COALESCE(v_booking.payment_status, 'unpaid') <> 'paid'
       AND COALESCE(v_booking.is_open_time, false) IS FALSE
       AND (v_booking.payment_method IS DISTINCT FROM 'cash'
         OR COALESCE(v_booking.payment_status, 'unpaid') NOT IN ('unpaid', 'partial'))) THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRED_BEFORE_SESSION_START' USING ERRCODE = '55000';
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
$function$;

CREATE OR REPLACE FUNCTION public.create_manual_booking_admin(
  p_lounge_id uuid,
  p_room_id uuid,
  p_booking_date date,
  p_start_time time without time zone,
  p_duration_minutes integer,
  p_customer_name text DEFAULT NULL,
  p_customer_phone text DEFAULT NULL,
  p_play_mode text DEFAULT 'single',
  p_extra_items jsonb DEFAULT '[]'::jsonb,
  p_start_immediately boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_booking public.bookings%ROWTYPE;
  v_booking_id uuid;
  v_shift_id uuid;
  v_end_ts timestamp;
  v_item jsonb;
  v_extra public.extras%ROWTYPE;
  v_extra_id uuid;
  v_quantity integer;
  v_line_total numeric;
  v_addons_total numeric := 0;
  v_session jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;

  IF p_lounge_id IS NULL OR p_room_id IS NULL
     OR p_booking_date IS NULL OR p_start_time IS NULL THEN
    RAISE EXCEPTION 'BOOKING_FIELDS_REQUIRED' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(p_lounge_id, 'bookings_create') THEN
    RAISE EXCEPTION 'BOOKING_CREATE_PERMISSION_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF p_duration_minutes IS NULL
     OR p_duration_minutes < 1
     OR p_duration_minutes > 1440 THEN
    RAISE EXCEPTION 'INVALID_BOOKING_DURATION' USING ERRCODE = '22023';
  END IF;

  IF p_extra_items IS NULL OR jsonb_typeof(p_extra_items) <> 'array'
     OR jsonb_array_length(p_extra_items) > 50 THEN
    RAISE EXCEPTION 'EXTRA_ITEMS_MUST_BE_ARRAY' USING ERRCODE = '22023';
  END IF;

  SELECT r.*
  INTO v_room
  FROM public.rooms AS r
  WHERE r.id = p_room_id
    AND r.lounge_id = p_lounge_id
    AND COALESCE(r.is_active, true) IS TRUE
    AND COALESCE(r.status, 'available') NOT IN ('maintenance', 'deleted')
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ROOM_NOT_BOOKABLE' USING ERRCODE = '55000';
  END IF;

  SELECT s.id
  INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.lounge_id = p_lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
  ORDER BY s.opened_at DESC
  LIMIT 1
  FOR SHARE;

  IF v_shift_id IS NULL THEN
    RAISE EXCEPTION 'NO_OPEN_SHIFT' USING ERRCODE = '55000';
  END IF;

  v_end_ts :=
    (p_booking_date + p_start_time)::timestamp
    + make_interval(mins => p_duration_minutes);

  INSERT INTO public.bookings (
    user_id,
    lounge_id,
    room_id,
    date,
    start_time,
    end_time,
    duration_minutes,
    status,
    payment_status,
    payment_method,
    user_name,
    user_phone,
    room_name,
    shift_id,
    play_mode,
    addons_price,
    addons_total
  )
  VALUES (
    NULL,
    p_lounge_id,
    p_room_id,
    p_booking_date,
    p_start_time,
    v_end_ts::time,
    p_duration_minutes,
    'pending'::public.booking_status,
    'unpaid',
    'cash',
    COALESCE(NULLIF(btrim(p_customer_name), ''), 'Walk-in Customer'),
    NULLIF(btrim(p_customer_phone), ''),
    COALESCE(v_room.name_ar, v_room.name_en, v_room.name),
    v_shift_id,
    COALESCE(NULLIF(btrim(lower(p_play_mode)), ''), 'single'),
    0,
    0
  )
  RETURNING *
  INTO v_booking;

  v_booking_id := v_booking.id;

  FOR v_item IN
    SELECT item.value
    FROM jsonb_array_elements(p_extra_items) AS item(value)
  LOOP
    IF jsonb_typeof(v_item) <> 'object'
       OR NULLIF(v_item->>'extra_id', '') IS NULL THEN
      RAISE EXCEPTION 'INVALID_EXTRA_ITEM' USING ERRCODE = '22023';
    END IF;

    BEGIN
      v_extra_id := (v_item->>'extra_id')::uuid;
      v_quantity := COALESCE((v_item->>'quantity')::integer, 1);
    EXCEPTION
      WHEN invalid_text_representation OR numeric_value_out_of_range THEN
        RAISE EXCEPTION 'INVALID_EXTRA_ITEM' USING ERRCODE = '22023';
    END;

    IF v_quantity < 1 OR v_quantity > 100 THEN
      RAISE EXCEPTION 'INVALID_EXTRA_QUANTITY' USING ERRCODE = '22023';
    END IF;

    SELECT e.*
    INTO v_extra
    FROM public.extras AS e
    WHERE e.id = v_extra_id
      AND e.lounge_id = p_lounge_id
      AND COALESCE(e.is_active, true) IS TRUE
      AND COALESCE(e.is_available, true) IS TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'EXTRA_NOT_AVAILABLE: %', v_extra_id
        USING ERRCODE = '23514';
    END IF;

    IF v_extra.price IS NULL OR v_extra.price < 0 THEN
      RAISE EXCEPTION 'INVALID_EXTRA_PRICE' USING ERRCODE = '23514';
    END IF;

    v_line_total := round(v_extra.price * v_quantity, 2);
    v_addons_total := v_addons_total + v_line_total;

    INSERT INTO public.booking_items (
      booking_id,
      product_id,
      extra_id,
      quantity,
      unit_price,
      total_price,
      price,
      name,
      status
    )
    VALUES (
      v_booking_id,
      v_extra.id,
      v_extra.id,
      v_quantity,
      v_extra.price,
      v_line_total,
      v_extra.price,
      COALESCE(v_extra.name_ar, v_extra.name_en, v_extra.name),
      'pending'
    );
  END LOOP;

  IF v_addons_total > 0 THEN
    UPDATE public.bookings AS b
    SET addons_price = v_addons_total,
        addons_total = v_addons_total,
        updated_at = now()
    WHERE b.id = v_booking_id
    RETURNING *
    INTO v_booking;
  END IF;

  IF p_start_immediately THEN
    -- Starting play is not evidence of cash collection.
    v_session := public.start_booking_session(v_booking_id);

    IF COALESCE((v_session->>'success')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'BOOKING_SESSION_NOT_STARTED' USING ERRCODE = '55000';
    END IF;
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = v_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking', to_jsonb(v_booking),
    'booking_id', v_booking_id,
    'addons_total', COALESCE(v_booking.addons_price, 0),
    'started', p_start_immediately
  );
END;
$function$;
NOTIFY pgrst, 'reload schema';
COMMIT;
