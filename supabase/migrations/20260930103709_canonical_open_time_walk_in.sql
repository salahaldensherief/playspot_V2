BEGIN;

CREATE OR REPLACE FUNCTION public.start_open_time_session(
  p_room_id uuid,
  p_customer_name text DEFAULT NULL,
  p_customer_phone text DEFAULT NULL,
  p_play_mode text DEFAULT 'single'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_shift uuid;
  v_booking uuid;
  v_now timestamptz := now();
  v_local timestamp := now() AT TIME ZONE 'Africa/Cairo';
  v_end timestamp;
  v_next timestamp;
  v_minutes integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_play_mode IS NULL OR p_play_mode NOT IN ('single', 'multi') THEN
    RAISE EXCEPTION 'INVALID_PLAY_MODE' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ROOM_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_room.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_lounge FROM public.lounges WHERE id = v_room.lounge_id FOR SHARE;
  IF NOT FOUND OR NOT COALESCE(v_lounge.allow_open_time_sessions, false) THEN
    RAISE EXCEPTION 'OPEN_TIME_DISABLED_FOR_LOUNGE' USING ERRCODE = '55000';
  END IF;
  IF NOT COALESCE(v_lounge.is_active, false)
     OR NOT COALESCE(v_lounge.is_open, false)
     OR v_lounge.status IS DISTINCT FROM 'approved' THEN
    RAISE EXCEPTION 'LOUNGE_NOT_AVAILABLE' USING ERRCODE = '55000';
  END IF;
  IF v_room.status IS DISTINCT FROM 'available'
     OR NOT COALESCE(v_room.is_available, false)
     OR NOT COALESCE(v_room.is_active, false) THEN
    RAISE EXCEPTION 'ROOM_NOT_AVAILABLE' USING ERRCODE = '55000';
  END IF;
  SELECT id INTO v_shift FROM public.shifts
  WHERE lounge_id = v_room.lounge_id AND status = 'open' AND closed_at IS NULL
  ORDER BY opened_at DESC LIMIT 1 FOR SHARE;
  IF v_shift IS NULL THEN
    RAISE EXCEPTION 'NO_OPEN_SHIFT' USING ERRCODE = '55000';
  END IF;
  IF EXISTS (SELECT 1 FROM public.bookings WHERE room_id = p_room_id
             AND status = 'in_progress'::public.booking_status) THEN
    RAISE EXCEPTION 'ROOM_HAS_ACTIVE_SESSION' USING ERRCODE = '55000';
  END IF;
  v_end := v_local + make_interval(mins => v_lounge.open_time_max_minutes);
  SELECT min(date + start_time) INTO v_next FROM public.bookings
  WHERE room_id = p_room_id
    AND status IN ('pending'::public.booking_status, 'upcoming'::public.booking_status)
    AND date + start_time > v_local;
  IF v_next IS NOT NULL THEN
    v_end := LEAST(v_end, v_next - interval '15 minutes');
  END IF;
  v_minutes := floor(extract(epoch FROM (v_end - v_local)) / 60)::integer;
  IF v_minutes IS NULL OR v_minutes < v_lounge.open_time_minimum_minutes THEN
    RAISE EXCEPTION 'NEXT_BOOKING_TOO_SOON' USING ERRCODE = '55000';
  END IF;
  INSERT INTO public.bookings (
    room_id, lounge_id, room_name, user_name, user_phone, date,
    start_time, end_time, start_at, end_at, duration_minutes,
    room_price, total_price, payment_method, payment_status, status,
    shift_id, play_mode, is_open_time, open_time_started_at, expires_at
  ) VALUES (
    p_room_id, v_room.lounge_id, v_room.name,
    NULLIF(btrim(p_customer_name), ''), NULLIF(btrim(p_customer_phone), ''),
    v_local::date, v_local::time, v_end::time, v_local::time, v_end::time,
    v_lounge.open_time_minimum_minutes, 0, 0, 'cash', 'unpaid', 'pending', v_shift,
    p_play_mode, true, v_now, NULL
  ) RETURNING id INTO v_booking;
  UPDATE public.bookings SET status = 'in_progress', actual_start_time = v_now,
    checked_in_at = v_now, updated_at = v_now WHERE id = v_booking;
  UPDATE public.rooms SET status = 'occupied', is_available = false,
    updated_at = v_now WHERE id = p_room_id;
  RETURN jsonb_build_object('success', true, 'booking_id', v_booking,
    'payment_status', 'unpaid', 'must_end_by', v_end);
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.start_open_time_session(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_open_time_session(uuid,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_booking_first_booking()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_completed_count integer;
BEGIN
  IF NEW.user_id IS NULL AND auth.uid() IS NOT NULL
     AND (public.is_super_admin()
       OR public.has_lounge_permission(NEW.lounge_id, 'sessions_control')) THEN
    NEW.is_first_booking := false;
    RETURN NEW;
  END IF;
  SELECT COALESCE(completed_bookings_count, 0) INTO v_completed_count
  FROM public.profiles WHERE id = NEW.user_id FOR UPDATE;
  NEW.is_first_booking := COALESCE(v_completed_count, 0) = 0;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_booking_payment(p_booking_id uuid, p_payment_method text DEFAULT 'cash'::text, p_final_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric;
  v_commission numeric;
  v_shift_id uuid;
  v_now_local timestamp without time zone := now() AT TIME ZONE 'Africa/Cairo';
  v_new_status public.booking_status;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_payment_method IS NULL OR p_payment_method NOT IN
     ('cash','manual_transfer','card','vodafone_cash','fawry','instapay','app_wallet') THEN
    RAISE EXCEPTION 'Invalid payment method' USING ERRCODE = '22023';
  END IF;

  SELECT b.* INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized for this lounge' USING ERRCODE = '42501';
  END IF;

  IF v_booking.payment_status = 'paid' THEN
    RAISE EXCEPTION 'Booking payment is already completed' USING ERRCODE = '55000';
  END IF;

  IF NOT (v_booking.is_open_time IS TRUE AND v_booking.status = 'completed'::public.booking_status)
     AND (v_booking.booking_period IS NULL OR v_now_local >= upper(v_booking.booking_period)) THEN
    RAISE EXCEPTION 'Booking period has already ended' USING ERRCODE = '55000';
  END IF;

  IF v_booking.total_price IS NULL OR v_booking.total_price < 0 THEN
    RAISE EXCEPTION 'Booking has an invalid server-calculated total' USING ERRCODE = '22023';
  END IF;

  IF p_final_amount IS NOT NULL AND round(p_final_amount, 2) <> round(v_booking.total_price, 2) THEN
    RAISE EXCEPTION 'Payment amount must match the booking total; update an approved discount before collecting' USING ERRCODE = '22023';
  END IF;

  v_amount := round(v_booking.total_price, 2);
  v_commission := round(v_amount * 0.15, 2);

  IF EXISTS (
    SELECT 1 FROM public.payments AS p
    WHERE p.booking_id = p_booking_id AND p.status = 'refunded'
  ) THEN
    RAISE EXCEPTION 'A refunded payment cannot be completed again through this RPC' USING ERRCODE = '55000';
  END IF;

  IF v_booking.status IN ('cancelled'::public.booking_status, 'rejected'::public.booking_status)
     OR (v_booking.status = 'completed'::public.booking_status AND NOT v_booking.is_open_time) THEN
    RAISE EXCEPTION 'BOOKING_NOT_PAYABLE' USING ERRCODE = '55000';
  END IF;

  v_new_status := CASE
    WHEN v_booking.is_open_time IS TRUE AND v_booking.status = 'completed'::public.booking_status
      THEN 'completed'::public.booking_status
    WHEN v_now_local >= lower(v_booking.booking_period) AND v_now_local < upper(v_booking.booking_period)
      THEN 'in_progress'::public.booking_status
    ELSE 'upcoming'::public.booking_status
  END;

  SELECT s.id INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.id = v_booking.shift_id AND s.lounge_id = v_booking.lounge_id
    AND s.status = 'open' AND s.closed_at IS NULL
  LIMIT 1 FOR SHARE;

  IF v_shift_id IS NULL THEN
    SELECT s.id INTO v_shift_id
    FROM public.shifts AS s
    WHERE s.lounge_id = v_booking.lounge_id AND s.status = 'open'
      AND s.closed_at IS NULL
    ORDER BY s.opened_at DESC
    LIMIT 1 FOR SHARE;
  END IF;

  IF v_shift_id IS NULL THEN
    RAISE EXCEPTION 'OPEN_SHIFT_REQUIRED_FOR_PAYMENT' USING ERRCODE = '55000';
  END IF;

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

  UPDATE public.bookings AS b
  SET status = v_new_status,
      payment_status = 'paid',
      payment_method = p_payment_method,
      total_price = v_amount,
      shift_id = v_shift_id,
      updated_at = now()
  WHERE b.id = p_booking_id;

  IF v_new_status = 'in_progress' AND v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms AS r
    SET status = 'occupied', is_available = false, updated_at = now()
    WHERE r.id = v_booking.room_id AND r.status NOT IN ('maintenance', 'deleted');
  END IF;

  IF v_shift_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.shift_payments AS sp WHERE sp.booking_id = p_booking_id
  ) THEN
    INSERT INTO public.shift_payments (
      shift_id, lounge_id, booking_id, payment_method, category, amount, paid_at
    ) VALUES (
      v_shift_id, v_booking.lounge_id, p_booking_id, p_payment_method, 'gaming_time', v_amount, now()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'room_id', v_booking.room_id,
    'status', v_new_status::text,
    'amount_paid', v_amount,
    'payment_method', p_payment_method,
    'commission', v_commission,
    'net_to_lounge', v_amount - v_commission
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.complete_booking_session(p_booking_id uuid, p_action_by uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_now timestamptz := now();
  v_now_local timestamp without time zone := now() AT TIME ZONE 'Africa/Cairo';
  v_started_at timestamptz;
  v_elapsed_minutes integer;
  v_billable_minutes integer;
  v_billable_capped integer;
  v_room_rate numeric;
  v_new_room_price numeric;
  v_existing_room_price numeric;
  v_non_room_total numeric;
  v_new_total numeric;
  v_delta numeric;
  v_payment_method text;
  v_shift_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_action_by IS DISTINCT FROM (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'Action user must be the authenticated user';
  END IF;

  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  PERFORM private.assert_lounge_operator(v_booking.lounge_id, true);
  IF v_booking.status = 'completed'::public.booking_status THEN
    RETURN json_build_object('success', true, 'booking_id', p_booking_id,
      'status', 'completed', 'final_total', v_booking.total_price);
  END IF;
  IF v_booking.status IS DISTINCT FROM 'in_progress'::public.booking_status THEN
    RAISE EXCEPTION 'SESSION_NOT_ACTIVE' USING ERRCODE = '55000';
  END IF;

  SELECT *
  INTO v_lounge
  FROM public.lounges
  WHERE id = v_booking.lounge_id
  FOR SHARE;

  IF v_booking.is_open_time IS TRUE THEN
    SELECT *
    INTO v_room
    FROM public.rooms
    WHERE id = v_booking.room_id
      AND lounge_id = v_booking.lounge_id
    FOR SHARE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Room not found';
    END IF;

    v_started_at :=
      COALESCE(v_booking.open_time_started_at, v_booking.actual_start_time, v_booking.checked_in_at);

    IF v_started_at IS NULL THEN
      RAISE EXCEPTION 'OPEN_TIME_START_MISSING' USING ERRCODE = '22023';
    END IF;

    v_elapsed_minutes :=
      GREATEST(1, CEIL(EXTRACT(EPOCH FROM (v_now - v_started_at)) / 60.0)::integer);

    v_billable_minutes :=
      CEIL(
        GREATEST(v_elapsed_minutes, COALESCE(v_lounge.open_time_minimum_minutes, 60))::numeric
        / COALESCE(NULLIF(v_lounge.open_time_rounding_minutes, 0), 15)
      )::integer
      * COALESCE(NULLIF(v_lounge.open_time_rounding_minutes, 0), 15);

    v_billable_capped :=
      LEAST(v_billable_minutes, COALESCE(v_lounge.open_time_max_minutes, 720));

    v_room_rate := CASE
      WHEN lower(COALESCE(v_booking.play_mode, '')) = 'single'
        THEN v_room.hourly_rate_single
      ELSE v_room.hourly_rate_multi
    END;

    IF v_room_rate IS NULL OR v_room_rate < 0 THEN
      RAISE EXCEPTION 'ROOM_RATE_NOT_CONFIGURED' USING ERRCODE = '22023';
    END IF;

    v_new_room_price := public.calculate_booking_price(v_room_rate, v_billable_capped);
    v_existing_room_price := COALESCE(v_booking.room_price, 0);
    v_non_room_total := COALESCE(v_booking.total_price, 0) - v_existing_room_price;
    v_new_total := GREATEST(0, v_new_room_price + v_non_room_total);
    v_delta := GREATEST(0, v_new_total - COALESCE(v_booking.total_price, 0));
    v_payment_method := COALESCE(v_booking.payment_method, 'cash');
    v_shift_id := v_booking.shift_id;

    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
        open_time_closed_at = v_now,
        open_time_billing_minutes = v_billable_capped,
        duration_minutes = v_billable_capped,
        room_price = v_new_room_price,
        total_price = v_new_total,
        end_time = v_now_local::time,
        end_at = v_now_local::time,
        updated_at = v_now
    WHERE id = p_booking_id;

    IF COALESCE(v_booking.payment_status, 'unpaid') = 'paid' AND v_delta > 0 THEN
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
        RAISE EXCEPTION 'OPEN_SHIFT_REQUIRED_FOR_OPEN_TIME_SETTLEMENT'
          USING ERRCODE = '55000';
      END IF;

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
        v_delta,
        v_now
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
        paid_at
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
        v_now
      )
      ON CONFLICT (booking_id)
      DO UPDATE SET
        amount = EXCLUDED.amount,
        commission = EXCLUDED.commission,
        net_to_lounge = EXCLUDED.net_to_lounge,
        payment_method = EXCLUDED.payment_method,
        status = 'completed',
        paid_at = COALESCE(public.payments.paid_at, EXCLUDED.paid_at);
    END IF;
  ELSE
    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
        updated_at = v_now
    WHERE id = p_booking_id;
  END IF;

  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms
    SET status = 'available',
        is_available = true,
        updated_at = v_now
    WHERE id = v_booking.room_id
      AND lounge_id = v_booking.lounge_id
      AND status = 'occupied';
  END IF;

  RETURN json_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'lounge_id', v_booking.lounge_id,
    'status', 'completed',
    'final_total', (SELECT total_price FROM public.bookings WHERE id = p_booking_id)
  );
END;
$function$

;
REVOKE EXECUTE ON FUNCTION public.complete_booking_payment(uuid,text,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_payment(uuid,text,numeric) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.complete_booking_session(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_session(uuid,uuid) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.set_booking_first_booking() FROM PUBLIC, anon, authenticated;
COMMIT;
