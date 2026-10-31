BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- Customer projection of existing audit rows. Never expose staff identities,
-- receipts, wallet numbers, payment details or arbitrary audit JSON.
CREATE OR REPLACE FUNCTION public.get_booking_timeline_for_customer(p_booking_id uuid)
RETURNS TABLE(id text,event_code text,title_ar text,title_en text,occurred_at timestamptz,payload jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT b.* INTO v_booking FROM public.bookings b
  WHERE b.id=p_booking_id AND b.user_id=auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_ACCESSIBLE' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  WITH recorded AS (
    SELECT 'audit:'||a.id::text event_id,a.created_at event_time,
      CASE
        WHEN a.action='insert' THEN 'booking_created'
        WHEN a.new_data->>'status' IS DISTINCT FROM a.old_data->>'status' THEN
          CASE a.new_data->>'status'
            WHEN 'in_progress' THEN 'booking_checked_in'
            WHEN 'completed' THEN 'booking_completed'
            WHEN 'cancelled' THEN 'booking_cancelled'
            WHEN 'upcoming' THEN 'booking_approved' END
        WHEN a.new_data->>'extension_status' IS DISTINCT FROM a.old_data->>'extension_status' THEN
          CASE a.new_data->>'extension_status'
            WHEN 'pending' THEN 'booking_extension_requested'
            WHEN 'approved' THEN 'booking_extension_approved'
            WHEN 'rejected' THEN 'booking_extension_rejected' END
      END code
    FROM public.shift_audit_logs a
    WHERE a.entity_type='booking' AND a.entity_id=p_booking_id
  ), fallback AS (
    SELECT 'booking:'||v_booking.id::text||':'||s.code event_id,s.event_time,s.code
    FROM (VALUES
      ('booking_created',v_booking.created_at),
      ('booking_approved',v_booking.approved_at),
      ('booking_checked_in',v_booking.checked_in_at),
      ('booking_cancelled',v_booking.cancelled_at),
      ('booking_completed',CASE WHEN v_booking.status='completed' THEN v_booking.cashier_closed_at END)
    ) s(code,event_time)
    WHERE s.event_time IS NOT NULL AND NOT EXISTS (SELECT 1 FROM recorded r WHERE r.code=s.code)
  ), events AS (
    SELECT * FROM recorded WHERE code IS NOT NULL
    UNION ALL SELECT * FROM fallback
  )
  SELECT e.event_id,e.code,
    CASE e.code
      WHEN 'booking_created' THEN 'تم إنشاء الحجز'
      WHEN 'booking_approved' THEN 'تم تأكيد الحجز'
      WHEN 'booking_checked_in' THEN 'بدأت الجلسة'
      WHEN 'booking_completed' THEN 'انتهت الجلسة'
      WHEN 'booking_cancelled' THEN 'تم إلغاء الحجز'
      WHEN 'booking_extension_requested' THEN 'طلب تمديد الجلسة'
      WHEN 'booking_extension_approved' THEN 'تمت الموافقة على التمديد'
      WHEN 'booking_extension_rejected' THEN 'تم رفض التمديد' END,
    CASE e.code
      WHEN 'booking_created' THEN 'Booking placed'
      WHEN 'booking_approved' THEN 'Booking confirmed'
      WHEN 'booking_checked_in' THEN 'Session started'
      WHEN 'booking_completed' THEN 'Session completed'
      WHEN 'booking_cancelled' THEN 'Booking cancelled'
      WHEN 'booking_extension_requested' THEN 'Extension requested'
      WHEN 'booking_extension_approved' THEN 'Extension approved'
      WHEN 'booking_extension_rejected' THEN 'Extension rejected' END,
    e.event_time,'{}'::jsonb
  FROM events e ORDER BY e.event_time,e.event_id;
END $$;
REVOKE ALL ON FUNCTION public.get_booking_timeline_for_customer(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_booking_timeline_for_customer(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION private.booking_extension_quote(p_booking public.bookings,p_minutes integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_start timestamp; v_end timestamp; v_quote jsonb; v_controller_rate numeric; v_cost numeric;
BEGIN
 IF p_minutes IS NULL OR p_minutes<=0 OR p_minutes>720 OR p_booking.is_open_time IS TRUE THEN
   RAISE EXCEPTION 'INVALID_FIXED_SESSION_EXTENSION' USING ERRCODE='22023';
 END IF;
 v_start:=p_booking.date+p_booking.start_time+make_interval(mins=>p_booking.duration_minutes);
 v_end:=v_start+make_interval(mins=>p_minutes);
 v_quote:=private.price_room_interval(p_booking.room_id,v_start::date,v_start::time,v_end::time,COALESCE(p_booking.play_mode,'single'));
 SELECT COALESCE(r.extra_controller_price,0) INTO v_controller_rate FROM public.rooms r WHERE r.id=p_booking.room_id;
 v_cost:=round((v_quote->>'room_subtotal')::numeric
   +GREATEST(0,COALESCE(p_booking.extra_controllers,0))*v_controller_rate*p_minutes/60.0,2);
 RETURN jsonb_build_object('extension_cost',v_cost,'new_total',COALESCE(p_booking.total_price,0)+v_cost,
   'room_price',COALESCE(p_booking.room_price,0)+v_cost,'quote',v_quote);
END $$;
REVOKE ALL ON FUNCTION private.booking_extension_quote(public.bookings,integer) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.fn_validate_and_clamp_booking_price()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_interval jsonb;
  v_room_subtotal numeric:=0;
  v_extra_controller_rate numeric:=0;
  v_controllers_amount numeric:=0;
  v_addons numeric:=0;
  v_subtotal numeric:=0;
  v_discount numeric:=0;
  v_snap jsonb;
  v_actual_hourly_rate numeric:=0;
BEGIN
  IF current_setting('app.skip_price_clamp',true)='true' THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.is_open_time,false) IS TRUE
     AND NEW.status='in_progress'::public.booking_status THEN
    NEW.duration_minutes:=GREATEST(1,COALESCE(NEW.duration_minutes,1));
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.duration_minutes,0)<=0 OR NEW.duration_minutes>1440 THEN
    RAISE EXCEPTION
      'Invalid booking duration: % minutes. Duration must be between 1 and 1440 minutes.',
      NEW.duration_minutes USING ERRCODE='22023';
  END IF;

  IF NEW.room_id IS NULL THEN
    RAISE EXCEPTION 'Cannot validate booking price: room_id is required.'
      USING ERRCODE='22023';
  END IF;

  -- Extend only the added interval; never reprice time already purchased.
  IF TG_OP='UPDATE' AND NEW.duration_minutes>OLD.duration_minutes
     AND NEW.extension_status='approved'
     AND COALESCE(NEW.is_open_time,false) IS FALSE
     AND ROW(NEW.room_id,NEW.date,NEW.start_time,NEW.play_mode,NEW.extra_controllers)
       IS NOT DISTINCT FROM ROW(OLD.room_id,OLD.date,OLD.start_time,OLD.play_mode,OLD.extra_controllers) THEN
    v_interval:=private.booking_extension_quote(OLD,NEW.duration_minutes-OLD.duration_minutes);
    NEW.room_price:=(v_interval->>'room_price')::numeric;
    NEW.total_price:=(v_interval->>'new_total')::numeric;
    NEW.addons_price:=OLD.addons_price;
    NEW.addons_total:=OLD.addons_total;
    NEW.discount_amount:=OLD.discount_amount;
    NEW.discount_percentage:=OLD.discount_percentage;
    NEW.pricing_snapshot:=jsonb_set(COALESCE(OLD.pricing_snapshot,'{}'::jsonb),'{extensions}',
      COALESCE(OLD.pricing_snapshot->'extensions','[]'::jsonb)||jsonb_build_array(v_interval->'quote'));
    SELECT ARRAY(SELECT DISTINCT unnest(COALESCE(OLD.pricing_rule_ids,'{}'::uuid[]) ||
      ARRAY(SELECT (s->>'rule_id')::uuid FROM jsonb_array_elements(v_interval->'quote'->'segments') s
       WHERE s->>'rule_id' IS NOT NULL))) INTO NEW.pricing_rule_ids;
    RETURN NEW;
  END IF;

  -- Status, payment and canteen updates must preserve the agreed room tariff.
  -- A schedule/mode/controller change deliberately requests a fresh price.
  IF TG_OP = 'UPDATE'
     AND COALESCE(NEW.is_open_time, false) IS FALSE
     AND ROW(NEW.room_id, NEW.date, NEW.start_time, NEW.end_time,
             NEW.duration_minutes, NEW.play_mode, NEW.extra_controllers, NEW.is_open_time)
         IS NOT DISTINCT FROM
         ROW(OLD.room_id, OLD.date, OLD.start_time, OLD.end_time,
             OLD.duration_minutes, OLD.play_mode, OLD.extra_controllers, OLD.is_open_time) THEN
    NEW.room_price := OLD.room_price;
    NEW.pricing_snapshot := OLD.pricing_snapshot;
    NEW.pricing_rule_ids := OLD.pricing_rule_ids;
  ELSIF COALESCE(NEW.is_open_time,false) IS TRUE
     AND NEW.open_time_pricing_snapshot IS NOT NULL
     AND NEW.open_time_pricing_snapshot<>'{}'::jsonb THEN
    v_snap:=NEW.open_time_pricing_snapshot;
    v_actual_hourly_rate:=COALESCE(
      (v_snap->>'effective_hourly_rate')::numeric,
      (v_snap->>'base_hourly_rate')::numeric,
      50
    );
    v_room_subtotal:=round(
      (NEW.duration_minutes/60.0)*v_actual_hourly_rate,
      2
    );
  ELSE
    IF NEW.date IS NULL OR NEW.start_time IS NULL OR NEW.end_time IS NULL THEN
      RAISE EXCEPTION 'Booking date/start/end are required for pricing'
        USING ERRCODE='22023';
    END IF;

    v_interval:=private.price_room_interval(
      NEW.room_id,
      NEW.date,
      NEW.start_time,
      NEW.end_time,
      COALESCE(NEW.play_mode,'single')
    );
    v_room_subtotal:=COALESCE(
      (v_interval->>'room_subtotal')::numeric,0
    );
  END IF;

  IF TG_OP = 'INSERT' OR COALESCE(NEW.is_open_time,false) IS TRUE
     OR ROW(NEW.room_id, NEW.date, NEW.start_time, NEW.end_time,
            NEW.duration_minutes, NEW.play_mode, NEW.extra_controllers, NEW.is_open_time)
        IS DISTINCT FROM
        ROW(OLD.room_id, OLD.date, OLD.start_time, OLD.end_time,
            OLD.duration_minutes, OLD.play_mode, OLD.extra_controllers, OLD.is_open_time) THEN
  SELECT
    GREATEST(0,COALESCE(NEW.extra_controllers,0))
    * COALESCE(r.extra_controller_price,0)
    * (NEW.duration_minutes/60.0)
  INTO v_controllers_amount
  FROM public.rooms AS r
  WHERE r.id=NEW.room_id;

  IF COALESCE(NEW.is_open_time,false) IS FALSE
     OR NEW.status='completed'::public.booking_status THEN
    NEW.room_price:=round(
      v_room_subtotal+COALESCE(v_controllers_amount,0),
      2
    );
  END IF;

  IF v_interval IS NOT NULL THEN
    NEW.pricing_snapshot := v_interval;
    SELECT COALESCE(array_agg(DISTINCT (segment->>'rule_id')::uuid)
      FILTER (WHERE segment->>'rule_id' IS NOT NULL), '{}'::uuid[])
    INTO NEW.pricing_rule_ids
    FROM jsonb_array_elements(v_interval->'segments') segment;
  END IF;
  END IF;

  v_addons:=GREATEST(
    0,COALESCE(NEW.addons_price,NEW.addons_total,0)
  );
  NEW.addons_price:=v_addons;
  NEW.addons_total:=v_addons;

  v_subtotal:=NEW.room_price+v_addons;

  IF COALESCE(NEW.discount_amount,0)>0 THEN
    v_discount:=LEAST(v_subtotal,NEW.discount_amount);
  ELSIF COALESCE(NEW.discount_percentage,0)>0 THEN
    v_discount:=LEAST(
      v_subtotal,
      v_subtotal*(NEW.discount_percentage/100.0)
    );
  ELSE
    v_discount:=0;
  END IF;

  NEW.discount_amount:=v_discount;
  NEW.total_price:=GREATEST(0,v_subtotal-v_discount);

  RETURN NEW;
END;
$function$
;
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
;
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

    UPDATE public.payments
    SET amount = amount + v_cost,
        commission = round((amount + v_cost) * 0.15, 2),
        net_to_lounge = (amount + v_cost) - round((amount + v_cost) * 0.15, 2)
    WHERE booking_id = p_booking_id;
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
