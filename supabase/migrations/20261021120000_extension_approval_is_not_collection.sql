-- An extension changes the service liability, never evidence of funds received.
-- Keep the old RPC signatures for deployed clients. Explicit cash collection is
-- public.collect_booking_cash_partial with its durable operation receipt.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.approve_booking_extension(p_booking_id uuid, p_additional_cost numeric DEFAULT NULL::numeric, p_payment_method text DEFAULT 'cash'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_new_duration integer;
  v_new_end timestamp without time zone;
  v_new_end_time time without time zone;
  v_hourly_rate numeric;
  v_cost numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;

  SELECT b.* INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  PERFORM private.assert_lounge_operator(v_booking.lounge_id, true);

  IF v_booking.status NOT IN ('upcoming'::public.booking_status, 'in_progress'::public.booking_status)
     OR COALESCE(v_booking.extension_status, 'none') <> 'pending'
     OR COALESCE(v_booking.requested_extension_minutes, 0) <= 0 THEN
    RAISE EXCEPTION 'NO_ELIGIBLE_PENDING_EXTENSION' USING ERRCODE = '55000';
  END IF;

  SELECT CASE
           WHEN lower(COALESCE(v_booking.play_mode, '')) = 'single' THEN r.hourly_rate_single
           ELSE r.hourly_rate_multi
         END
  INTO v_hourly_rate
  FROM public.rooms AS r
  WHERE r.id = v_booking.room_id
    AND r.lounge_id = v_booking.lounge_id;

  IF v_hourly_rate IS NULL OR v_hourly_rate < 0 THEN
    RAISE EXCEPTION 'ROOM_RATE_NOT_CONFIGURED' USING ERRCODE = '22023';
  END IF;

  v_new_duration := COALESCE(v_booking.duration_minutes, 0) + v_booking.requested_extension_minutes;
  IF v_new_duration <= 0 OR v_new_duration > 1440 THEN
    RAISE EXCEPTION 'INVALID_TOTAL_SESSION_DURATION' USING ERRCODE = '22023';
  END IF;

  v_new_end := v_booking.date + v_booking.start_time + make_interval(mins => v_new_duration);
  v_new_end_time := v_new_end::time;
  v_cost := (private.booking_extension_quote(v_booking,v_booking.requested_extension_minutes)->>'extension_cost')::numeric;

  IF EXISTS (
    SELECT 1
    FROM public.bookings AS next_booking
    WHERE next_booking.id <> v_booking.id
      AND next_booking.room_id = v_booking.room_id
      AND next_booking.status IN ('pending'::public.booking_status, 'upcoming'::public.booking_status, 'in_progress'::public.booking_status)
      AND next_booking.booking_period IS NOT NULL
      AND next_booking.booking_period && tsrange(
        (v_booking.date + v_booking.start_time)::timestamp,
        v_new_end,
        '[)'
      )
      AND (next_booking.status <> 'pending'::public.booking_status
           OR next_booking.expires_at IS NULL
           OR next_booking.expires_at > now())
  ) THEN
    RAISE EXCEPTION 'BOOKING_EXTENSION_CONFLICT' USING ERRCODE = '23P01';
  END IF;

  UPDATE public.bookings AS b
  SET duration_minutes = v_new_duration,
      end_time = v_new_end_time,
      end_at = v_new_end_time,
      total_price = COALESCE(b.total_price, 0) + v_cost,
      payment_status = CASE WHEN v_cost > 0 AND b.payment_status = 'paid' THEN 'partial' ELSE b.payment_status END,
      extension_status = 'approved',
      requested_extension_minutes = NULL,
      updated_at = now()
  WHERE b.id = p_booking_id;

  IF (SELECT b.total_price FROM public.bookings b WHERE b.id=p_booking_id) IS DISTINCT FROM COALESCE(v_booking.total_price,0)+v_cost THEN
    RAISE EXCEPTION 'EXTENSION_PRICE_MISMATCH' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.notifications(
    user_id, lounge_id, title_ar, title_en, body_ar, body_en, type, is_read, metadata
  ) VALUES (
    v_booking.user_id, v_booking.lounge_id,
    'تمت الموافقة على تمديد الحجز ✅', 'Booking Extension Approved ✅',
    'تمت الموافقة على طلب تمديد وقت الحجز بمقدار ' || v_booking.requested_extension_minutes || ' دقيقة.',
    'Your booking extension request was approved for ' || v_booking.requested_extension_minutes || ' minutes.',
    'booking_extension_approved', false,
    jsonb_build_object(
      'booking_id', p_booking_id,
      'extension_minutes', v_booking.requested_extension_minutes,
      'extension_cost', v_cost
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'status', 'approved',
    'booking_id', p_booking_id,
    'new_duration', v_new_duration,
    'new_end_time', v_new_end_time,
    'extension_cost', v_cost,
    'new_total', COALESCE(v_booking.total_price, 0) + v_cost,
    'shift_payment_recorded', false
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.extend_booking_session(p_booking_id uuid, p_additional_minutes integer, p_additional_cost numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_is_operator boolean := false;
  v_hourly_rate numeric;
  v_extension_cost numeric;
  v_new_duration integer;
  v_new_end timestamp without time zone;
  v_new_end_time time without time zone;
  v_new_total numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;

  IF p_additional_minutes IS NULL
     OR p_additional_minutes <= 0
     OR p_additional_minutes > 720 THEN
    RAISE EXCEPTION 'INVALID_EXTENSION_MINUTES' USING ERRCODE = '22023';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  IF v_booking.status NOT IN (
    'upcoming'::public.booking_status,
    'in_progress'::public.booking_status
  ) THEN
    RAISE EXCEPTION 'BOOKING_NOT_EXTENDABLE' USING ERRCODE = '55000';
  END IF;

  v_is_operator :=
    public.is_super_admin()
    OR public.has_lounge_permission(v_booking.lounge_id, 'sessions_control');

  IF NOT v_is_operator THEN
    IF v_booking.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF COALESCE(v_booking.extension_status, 'none') = 'pending' THEN
      RETURN jsonb_build_object(
        'success', true,
        'status', 'pending',
        'already_pending', true,
        'booking_id', p_booking_id,
        'requested_extension_minutes', v_booking.requested_extension_minutes
      );
    END IF;

    UPDATE public.bookings
    SET extension_status = 'pending',
        requested_extension_minutes = p_additional_minutes,
        updated_at = now()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'pending',
      'already_pending', false,
      'booking_id', p_booking_id,
      'requested_extension_minutes', p_additional_minutes
    );
  END IF;

  SELECT CASE
           WHEN lower(COALESCE(v_booking.play_mode, '')) = 'single'
             THEN r.hourly_rate_single
           ELSE r.hourly_rate_multi
         END
  INTO v_hourly_rate
  FROM public.rooms AS r
  WHERE r.id = v_booking.room_id
    AND r.lounge_id = v_booking.lounge_id;

  IF v_hourly_rate IS NULL OR v_hourly_rate < 0 THEN
    RAISE EXCEPTION 'ROOM_RATE_NOT_CONFIGURED' USING ERRCODE = '22023';
  END IF;

  v_new_duration :=
    COALESCE(v_booking.duration_minutes, 0) + p_additional_minutes;

  IF v_new_duration <= 0 OR v_new_duration > 1440 THEN
    RAISE EXCEPTION 'INVALID_TOTAL_SESSION_DURATION' USING ERRCODE = '22023';
  END IF;

  v_new_end :=
    v_booking.date
    + v_booking.start_time
    + make_interval(mins => v_new_duration);

  v_new_end_time := v_new_end::time;

  IF EXISTS (
    SELECT 1
    FROM public.bookings AS next_booking
    WHERE next_booking.id <> v_booking.id
      AND next_booking.room_id = v_booking.room_id
      AND next_booking.status IN (
        'pending'::public.booking_status,
        'upcoming'::public.booking_status,
        'in_progress'::public.booking_status
      )
      AND next_booking.booking_period IS NOT NULL
      AND next_booking.booking_period && tsrange(
        (v_booking.date + v_booking.start_time)::timestamp,
        v_new_end,
        '[)'
      )
      AND (
        next_booking.status <> 'pending'::public.booking_status
        OR next_booking.expires_at IS NULL
        OR next_booking.expires_at > now()
      )
  ) THEN
    RAISE EXCEPTION 'BOOKING_EXTENSION_CONFLICT' USING ERRCODE = '23P01';
  END IF;

  v_extension_cost :=
    (private.booking_extension_quote(v_booking,p_additional_minutes)->>'extension_cost')::numeric;

  v_new_total :=
    COALESCE(v_booking.total_price, 0) + v_extension_cost;

  UPDATE public.bookings
  SET duration_minutes = v_new_duration,
      end_time = v_new_end_time,
      end_at = v_new_end_time,
      total_price = v_new_total,
      payment_status = CASE WHEN v_extension_cost > 0 AND payment_status = 'paid' THEN 'partial' ELSE payment_status END,
      extension_status = 'approved',
      requested_extension_minutes = NULL,
      updated_at = now()
  WHERE id = p_booking_id;

  IF (SELECT b.total_price FROM public.bookings b WHERE b.id=p_booking_id) IS DISTINCT FROM v_new_total THEN
    RAISE EXCEPTION 'EXTENSION_PRICE_MISMATCH' USING ERRCODE='22023';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'approved',
    'booking_id', p_booking_id,
    'added_minutes', p_additional_minutes,
    'extension_cost', v_extension_cost,
    'new_duration', v_new_duration,
    'new_end_time', v_new_end_time,
    'new_total', v_new_total,
    'ignored_client_cost', p_additional_cost
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.approve_booking_extension(uuid,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_booking_extension(uuid,numeric,text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.extend_booking_session(uuid,integer,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.extend_booking_session(uuid,integer,numeric) TO authenticated, service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
