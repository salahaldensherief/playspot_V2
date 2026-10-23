-- AUDIT SNAPSHOT ONLY. Captured read-only 2026-10-21. Do not deploy.
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
  v_shift_id uuid;
  v_payment_method text;
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

  IF v_booking.payment_status = 'paid' AND v_extension_cost > 0 THEN
    SELECT s.id
    INTO v_shift_id
    FROM public.shifts AS s
    WHERE s.id = v_booking.shift_id
      AND s.lounge_id = v_booking.lounge_id
      AND s.status = 'open'
    LIMIT 1;

    IF v_shift_id IS NULL THEN
      SELECT s.id
      INTO v_shift_id
      FROM public.shifts AS s
      WHERE s.lounge_id = v_booking.lounge_id
        AND s.status = 'open'
      ORDER BY s.opened_at DESC
      LIMIT 1;
    END IF;

    IF v_shift_id IS NULL THEN
      RAISE EXCEPTION 'OPEN_SHIFT_REQUIRED_FOR_PAID_EXTENSION'
        USING ERRCODE = '55000';
    END IF;

    v_payment_method := COALESCE(v_booking.payment_method, 'cash');

    INSERT INTO public.shift_payments (
      shift_id,
      lounge_id,
      booking_id,
      payment_method,
      category,
      amount,
      paid_at
    )
    VALUES (
      v_shift_id,
      v_booking.lounge_id,
      p_booking_id,
      v_payment_method,
      'gaming_time',
      v_extension_cost,
      now()
    );

    INSERT INTO public.payments (
      booking_id,
      user_id,
      lounge_id,
      amount,
      commission,
      net_to_lounge,
      payment_method,
      status,
      paid_at,
      discount_amount,
      discount_percentage,
      discount_reason,
      discount_approved_by
    )
    VALUES (
      p_booking_id,
      v_booking.user_id,
      v_booking.lounge_id,
      v_new_total,
      round(v_new_total * 0.15, 2),
      v_new_total - round(v_new_total * 0.15, 2),
      v_payment_method,
      'completed',
      now(),
      COALESCE(v_booking.discount_amount, 0),
      COALESCE(v_booking.discount_percentage, 0),
      v_booking.discount_reason,
      v_booking.discount_approved_by
    )
    ON CONFLICT (booking_id)
    DO UPDATE SET
      amount = EXCLUDED.amount,
      commission = EXCLUDED.commission,
      net_to_lounge = EXCLUDED.net_to_lounge,
      payment_method = EXCLUDED.payment_method,
      status = 'completed',
      paid_at = COALESCE(public.payments.paid_at, EXCLUDED.paid_at),
      discount_amount = EXCLUDED.discount_amount,
      discount_percentage = EXCLUDED.discount_percentage,
      discount_reason = EXCLUDED.discount_reason,
      discount_approved_by = EXCLUDED.discount_approved_by;
  END IF;

  UPDATE public.bookings
  SET duration_minutes = v_new_duration,
      end_time = v_new_end_time,
      end_at = v_new_end_time,
      total_price = v_new_total,
      shift_id = COALESCE(v_shift_id, shift_id),
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
$function$
