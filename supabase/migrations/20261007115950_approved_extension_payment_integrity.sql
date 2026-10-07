BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
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
  v_shift_id uuid;
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

  SELECT s.id INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.lounge_id = v_booking.lounge_id AND s.status = 'open'
  ORDER BY s.opened_at DESC
  LIMIT 1;

  IF v_booking.payment_status = 'paid' AND v_cost > 0 AND v_shift_id IS NOT NULL THEN
    INSERT INTO public.shift_payments (
      shift_id, lounge_id, booking_id, payment_method, category, amount, paid_at
    ) VALUES (
      v_shift_id, v_booking.lounge_id, p_booking_id, 
      COALESCE(p_payment_method, v_booking.payment_method, 'cash'), 
      'gaming_time', v_cost, now()
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
      (COALESCE(v_booking.total_price,0)+v_cost),
      round((COALESCE(v_booking.total_price,0)+v_cost) * 0.15, 2),
      (COALESCE(v_booking.total_price,0)+v_cost) - round((COALESCE(v_booking.total_price,0)+v_cost) * 0.15, 2),
      COALESCE(p_payment_method,v_booking.payment_method,'cash'),
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


  UPDATE public.bookings AS b
  SET duration_minutes = v_new_duration,
      end_time = v_new_end_time,
      end_at = v_new_end_time,
      total_price = COALESCE(b.total_price, 0) + v_cost,
      extension_status = 'approved',
      requested_extension_minutes = NULL,
      updated_at = now()
  WHERE b.id = p_booking_id;

  IF (SELECT b.total_price FROM public.bookings b WHERE b.id=p_booking_id) IS DISTINCT FROM COALESCE(v_booking.total_price,0)+v_cost THEN
    RAISE EXCEPTION 'EXTENSION_PRICE_MISMATCH' USING ERRCODE='22023';
  END IF;
  IF v_booking.payment_status='paid' AND v_cost>0 AND v_shift_id IS NULL THEN
    RAISE EXCEPTION 'OPEN_SHIFT_REQUIRED_FOR_PAID_EXTENSION' USING ERRCODE='55000';
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
    'shift_payment_recorded', (v_booking.payment_status = 'paid' AND v_cost > 0)
  );
END;
$function$
;

NOTIFY pgrst,'reload schema';
COMMIT;
