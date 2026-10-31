BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS pricing_rule_ids uuid[] NOT NULL DEFAULT '{}'::uuid[];

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

CREATE OR REPLACE FUNCTION public.create_my_booking_checkout(p_hold_token uuid, p_room_requests jsonb, p_extra_items jsonb DEFAULT '[]'::jsonb, p_voucher_code text DEFAULT NULL::text, p_payment_method text DEFAULT 'cash'::text, p_sender_wallet_phone text DEFAULT NULL::text, p_receipt_url text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_quote jsonb;
  v_lounge_id uuid;
  v_start_at timestamp without time zone;
  v_end_at timestamp without time zone;
  v_duration_minutes integer;
  v_room jsonb;
  v_room_id uuid;
  v_room_name text;
  v_play_mode text;
  v_extra_controllers integer;
  v_room_price numeric;
  v_promo_discount numeric;
  v_voucher_discount numeric := 0;
  v_discount_amount numeric;
  v_discount_percentage numeric;
  v_discount_label text;
  v_primary boolean := true;
  v_booking_id uuid;
  v_primary_booking_id uuid;
  v_booking_ids jsonb := '[]'::jsonb;
  v_user_name text;
  v_user_phone text;
  v_clean_payment_method text := lower(btrim(COALESCE(p_payment_method, '')));
  v_clean_sender text := NULLIF(btrim(p_sender_wallet_phone), '');
  v_clean_receipt text := NULLIF(btrim(p_receipt_url), '');
  v_canteen_items jsonb := '[]'::jsonb;
  v_remaining_voucher numeric;
  v_voucher_share numeric;
  v_booking public.bookings%ROWTYPE;
  v_persisted_total numeric;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF v_clean_payment_method NOT IN ('cash', 'manual_transfer') THEN
    RAISE EXCEPTION 'Invalid payment method' USING ERRCODE = '22023';
  END IF;

  IF v_clean_payment_method = 'manual_transfer'
     AND v_clean_sender IS NULL THEN
    RAISE EXCEPTION 'sender_wallet_phone is required for manual_transfer'
      USING ERRCODE = '22023';
  END IF;

  PERFORM 1
  FROM public.booking_holds h
  WHERE h.hold_token = p_hold_token
    AND h.user_id = v_user_id
    AND h.released_at IS NULL
    AND h.expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_HOLD_EXPIRED' USING ERRCODE = '55000';
  END IF;

  v_quote := private.build_my_booking_checkout_quote(
    v_user_id,
    p_hold_token,
    p_room_requests,
    p_extra_items,
    p_voucher_code
  );

  v_lounge_id := (v_quote->>'lounge_id')::uuid;
  v_start_at := (v_quote->>'start_at')::timestamp;
  v_end_at := (v_quote->>'end_at')::timestamp;
  v_duration_minutes := (v_quote->>'duration_minutes')::integer;
  v_voucher_discount := COALESCE(
    (v_quote->>'voucher_discount')::numeric,
    0
  );

  SELECT
    p.full_name,
    p.phone
  INTO
    v_user_name,
    v_user_phone
  FROM public.profiles p
  WHERE p.id = v_user_id;

  FOR v_room IN
    SELECT r.value
    FROM jsonb_array_elements(v_quote->'rooms') WITH ORDINALITY r(value, ord)
    ORDER BY r.ord
  LOOP
    v_room_id := (v_room->>'room_id')::uuid;
    v_room_name := COALESCE(
      NULLIF(v_room->>'room_name_en', ''),
      NULLIF(v_room->>'room_name_ar', ''),
      ''
    );
    v_play_mode := v_room->>'play_mode';
    v_extra_controllers := COALESCE(
      (v_room->>'extra_controllers')::integer,
      0
    );
    v_room_price := COALESCE(
      (v_room->>'original_subtotal')::numeric,
      0
    );
    v_promo_discount := COALESCE(
      (v_room->>'promo_discount_amount')::numeric,
      0
    );

    v_discount_amount :=
      v_promo_discount;

    v_discount_percentage := CASE
      WHEN lower(COALESCE(v_room->>'discount_type', '')) = 'percentage'
      THEN COALESCE((v_room->>'discount_value')::numeric, 0)
      ELSE 0
    END;

    v_discount_label := NULLIF(v_room->>'discount_label', '');

    INSERT INTO public.bookings (
      user_id,
      room_id,
      lounge_id,
      date,
      start_time,
      end_time,
      room_price,
      addons_price,
      addons_total,
      total_price,
      status,
      user_name,
      user_phone,
      room_name,
      duration_minutes,
      play_mode,
      extra_controllers,
      payment_status,
      payment_method,
      discount_amount,
      discount_percentage,
      discount_reason,
      receipt_url,
      sender_wallet_phone
    )
    VALUES (
      v_user_id,
      v_room_id,
      v_lounge_id,
      v_start_at::date,
      v_start_at::time,
      v_end_at::time,
      v_room_price,
      0,
      0,
      GREATEST(0, v_room_price - v_discount_amount),
      'pending'::public.booking_status,
      v_user_name,
      v_user_phone,
      v_room_name,
      v_duration_minutes,
      v_play_mode,
      v_extra_controllers,
      'unpaid',
      v_clean_payment_method,
      v_discount_amount,
      v_discount_percentage,
      v_discount_label,
      v_clean_receipt,
      CASE
        WHEN v_clean_payment_method = 'manual_transfer'
        THEN v_clean_sender
        ELSE NULL
      END
    )
    RETURNING id INTO v_booking_id;

    IF v_primary THEN
      v_primary_booking_id := v_booking_id;
    END IF;

    v_booking_ids :=
      v_booking_ids || jsonb_build_array(v_booking_id);

    v_primary := false;
  END LOOP;

  IF jsonb_array_length(COALESCE(v_quote->'extras', '[]'::jsonb)) > 0 THEN
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'extra_id', item.value->>'extra_id',
          'quantity', (item.value->>'quantity')::integer
        )
      ),
      '[]'::jsonb
    )
    INTO v_canteen_items
    FROM jsonb_array_elements(v_quote->'extras') item(value);

    PERFORM public.place_canteen_order(
      v_primary_booking_id,
      v_canteen_items,
      NULL
    );
  END IF;

  -- Extras are attached before allocating the voucher, so a fixed voucher can
  -- cover their price and spill across rooms without the row clamp losing it.
  v_remaining_voucher := v_voucher_discount;
  FOR v_booking IN
    SELECT b.* FROM jsonb_array_elements_text(v_booking_ids)
      WITH ORDINALITY ids(id, ord)
    JOIN public.bookings b ON b.id = ids.id::uuid
    ORDER BY ids.ord
    FOR UPDATE OF b
  LOOP
    v_voucher_share := LEAST(v_remaining_voucher, v_booking.total_price);
    IF v_voucher_share > 0 THEN
      UPDATE public.bookings
      SET discount_amount = COALESCE(v_booking.discount_amount, 0) + v_voucher_share,
          discount_reason = concat_ws(' + ', NULLIF(v_booking.discount_reason, ''), 'voucher'),
          applied_voucher_code = upper(btrim(p_voucher_code)),
          updated_at = now()
      WHERE id = v_booking.id;
      v_remaining_voucher := v_remaining_voucher - v_voucher_share;
    END IF;
  END LOOP;

  SELECT COALESCE(sum(b.total_price), 0)
  INTO v_persisted_total
  FROM public.bookings b
  WHERE b.id IN (SELECT value::uuid FROM jsonb_array_elements_text(v_booking_ids));
  IF v_remaining_voucher <> 0
     OR v_persisted_total IS DISTINCT FROM (v_quote->>'final_total')::numeric THEN
    RAISE EXCEPTION 'CHECKOUT_PRICE_CHANGED' USING ERRCODE = '40001';
  END IF;

  IF NULLIF(btrim(p_voucher_code), '') IS NOT NULL THEN
    IF NOT public.consume_voucher_by_code(
      p_voucher_code,
      v_primary_booking_id
    ) THEN
      RAISE EXCEPTION 'VOUCHER_CONSUMPTION_FAILED'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  UPDATE public.booking_holds
  SET released_at = now()
  WHERE hold_token = p_hold_token
    AND user_id = v_user_id
    AND released_at IS NULL;

  RETURN jsonb_build_object(
    'success', true,
    'primary_booking_id', v_primary_booking_id,
    'booking_ids', v_booking_ids,
    'quote', v_quote
  );
END;
$function$
;

REVOKE ALL ON FUNCTION public.create_my_booking_checkout(uuid,jsonb,jsonb,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_my_booking_checkout(uuid,jsonb,jsonb,text,text,text,text) TO authenticated, service_role;
CREATE OR REPLACE FUNCTION public.consume_voucher_by_code(p_code text, p_booking_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = p_booking_id AND b.user_id = v_user_id) THEN
    RAISE EXCEPTION 'Voucher booking mismatch' USING ERRCODE = '42501';
  END IF;

  UPDATE public.user_vouchers
  SET status = 'used',
      used_at = NOW(),
      used_booking_id = p_booking_id
  WHERE UPPER(TRIM(code)) = UPPER(TRIM(p_code))
    AND user_id = v_user_id
    AND status = 'active'
    AND (expires_at IS NULL OR expires_at >= NOW());

  RETURN FOUND;
END;
$function$
;
REVOKE ALL ON FUNCTION public.consume_voucher_by_code(text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consume_voucher_by_code(text,uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.build_my_booking_checkout_quote(p_user_id uuid, p_hold_token uuid, p_room_requests jsonb, p_extra_items jsonb DEFAULT '[]'::jsonb, p_voucher_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_hold_count integer;
  v_request_count integer;
  v_lounge_id uuid;
  v_start_at timestamp without time zone;
  v_end_at timestamp without time zone;
  v_duration_hours numeric;
  v_request jsonb;
  v_room_id uuid;
  v_play_mode text;
  v_extra_controllers integer;
  v_room record;
  v_base_rate numeric;
  v_pricing jsonb;
  v_priced_room_subtotal numeric;
  v_effective_rate numeric;
  v_controller_rate numeric;
  v_discounted_base_rate numeric;
  v_original_subtotal numeric;
  v_discounted_subtotal numeric;
  v_promo_discount numeric;
  v_discount_type text;
  v_discount_value numeric;
  v_discount_label text;
  v_discount_source text;
  v_rooms jsonb := '[]'::jsonb;
  v_original_rooms_total numeric := 0;
  v_discounted_rooms_total numeric := 0;
  v_room_discount_total numeric := 0;
  v_primary_rate numeric := 0;
  v_primary_discounted_subtotal numeric := 0;
  v_extra jsonb;
  v_extra_id uuid;
  v_quantity integer;
  v_extra_row record;
  v_extras jsonb := '[]'::jsonb;
  v_extras_total numeric := 0;
  v_voucher public.user_vouchers%ROWTYPE;
  v_voucher_discount numeric := 0;
  v_voucher_code text := NULLIF(upper(btrim(p_voucher_code)), '');
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_hold_token IS NULL THEN
    RAISE EXCEPTION 'Booking hold is required' USING ERRCODE = '22023';
  END IF;

  SELECT count(*)
  INTO v_hold_count
  FROM public.booking_holds h
  WHERE h.hold_token = p_hold_token
    AND h.user_id = p_user_id
    AND h.released_at IS NULL
    AND h.expires_at > now();

  IF v_hold_count < 1 THEN
    RAISE EXCEPTION 'BOOKING_HOLD_EXPIRED' USING ERRCODE = '55000';
  END IF;

  SELECT h.lounge_id, h.start_at, h.end_at
  INTO v_lounge_id, v_start_at, v_end_at
  FROM public.booking_holds h
  WHERE h.hold_token = p_hold_token
    AND h.user_id = p_user_id
    AND h.released_at IS NULL
    AND h.expires_at > now()
  ORDER BY h.id
  LIMIT 1;

  IF EXISTS (
    SELECT 1
    FROM public.booking_holds h
    WHERE h.hold_token = p_hold_token
      AND h.user_id = p_user_id
      AND (
        h.lounge_id IS DISTINCT FROM v_lounge_id
        OR h.start_at IS DISTINCT FROM v_start_at
        OR h.end_at IS DISTINCT FROM v_end_at
      )
  ) THEN
    RAISE EXCEPTION 'Invalid booking hold' USING ERRCODE = '23514';
  END IF;

  IF p_room_requests IS NULL
     OR jsonb_typeof(p_room_requests) <> 'array'
     OR jsonb_array_length(p_room_requests) < 1 THEN
    RAISE EXCEPTION 'Room requests must be a non-empty JSON array'
      USING ERRCODE = '22023';
  END IF;

  IF v_start_at IS DISTINCT FROM date_trunc('minute',v_start_at)
     OR v_end_at IS DISTINCT FROM date_trunc('minute',v_end_at) THEN
    RAISE EXCEPTION 'Booking intervals must use whole minutes' USING ERRCODE = '22023';
  END IF;

  v_request_count := jsonb_array_length(p_room_requests);

  IF v_request_count <> v_hold_count THEN
    RAISE EXCEPTION 'Room request count does not match booking hold'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_room_requests) req(value)
    LEFT JOIN public.booking_holds h
      ON h.hold_token = p_hold_token
     AND h.user_id = p_user_id
     AND h.room_id = NULLIF(req.value->>'room_id', '')::uuid
     AND h.released_at IS NULL
     AND h.expires_at > now()
    WHERE h.id IS NULL
  ) THEN
    RAISE EXCEPTION 'Room request is not covered by the booking hold'
      USING ERRCODE = '23514';
  END IF;

  IF (
    SELECT count(DISTINCT req.value->>'room_id')
    FROM jsonb_array_elements(p_room_requests) req(value)
  ) <> v_request_count THEN
    RAISE EXCEPTION 'Duplicate room request' USING ERRCODE = '22023';
  END IF;

  v_duration_hours :=
    extract(epoch FROM (v_end_at - v_start_at)) / 3600.0;

  IF v_duration_hours <= 0 OR v_duration_hours > 24 THEN
    RAISE EXCEPTION 'Invalid booking duration' USING ERRCODE = '22023';
  END IF;

  FOR v_request IN
    SELECT req.value
    FROM jsonb_array_elements(p_room_requests) WITH ORDINALITY req(value, ord)
    ORDER BY req.ord
  LOOP
    BEGIN
      v_room_id := NULLIF(v_request->>'room_id', '')::uuid;
      v_extra_controllers :=
        GREATEST(0, COALESCE((v_request->>'extra_controllers')::integer, 0));
    EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
      RAISE EXCEPTION 'Invalid room request' USING ERRCODE = '22023';
    END;

    IF v_extra_controllers > 20 THEN
      RAISE EXCEPTION 'Too many extra controllers requested'
        USING ERRCODE = '22023';
    END IF;

    v_play_mode := lower(COALESCE(NULLIF(v_request->>'play_mode', ''), 'single'));
    IF v_play_mode NOT IN ('single', 'multi') THEN
      RAISE EXCEPTION 'Invalid play mode' USING ERRCODE = '22023';
    END IF;

    SELECT
      r.id,
      r.lounge_id,
      r.name_ar,
      r.name_en,
      r.hourly_rate_single,
      r.hourly_rate_multi,
      r.extra_controller_price
    INTO v_room
    FROM public.rooms r
    WHERE r.id = v_room_id
      AND r.lounge_id = v_lounge_id
      AND r.is_active IS TRUE
      AND COALESCE(r.status, 'available') NOT IN ('maintenance','deleted');

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Room unavailable: %', v_room_id
        USING ERRCODE = '23514';
    END IF;

    v_base_rate := CASE
      WHEN v_play_mode = 'multi'
        AND COALESCE(v_room.hourly_rate_multi, 0) > 0
      THEN v_room.hourly_rate_multi
      ELSE v_room.hourly_rate_single
    END;

    IF COALESCE(v_base_rate, 0) <= 0 THEN
      RAISE EXCEPTION 'Room has no valid hourly rate: %', v_room_id
        USING ERRCODE = '23514';
    END IF;

    v_pricing := private.price_room_interval(
      v_room_id,
      v_start_at::date,
      v_start_at::time,
      v_end_at::time,
      v_play_mode
    );
    v_effective_rate := COALESCE(
      (v_pricing->>'effective_hourly_rate')::numeric,
      v_base_rate
    );
    v_priced_room_subtotal := COALESCE(
      (v_pricing->>'room_subtotal')::numeric,
      v_base_rate * v_duration_hours
    );

    v_controller_rate :=
      v_extra_controllers * COALESCE(v_room.extra_controller_price, 0);

    v_discounted_base_rate := v_effective_rate;
    v_discount_type := NULL;
    v_discount_value := 0;
    v_discount_label := NULL;
    v_discount_source := 'none';

    SELECT
      p.discount_type,
      COALESCE(p.discount_value, 0),
      COALESCE(p.tag_en, p.tag_ar, p.title_en, p.title_ar, p.title)
    INTO
      v_discount_type,
      v_discount_value,
      v_discount_label
    FROM public.promotions p
    WHERE p.is_active IS TRUE
      AND p.room_id = v_room_id
      AND COALESCE(p.discount_value, 0) > 0
      AND (p.expires_at IS NULL OR p.expires_at > now())
    ORDER BY p.created_at DESC, p.id DESC
    LIMIT 1;

    IF FOUND THEN
      v_discount_source := 'room';
    ELSE
      SELECT
        p.discount_type,
        COALESCE(p.discount_value, 0),
        COALESCE(p.tag_en, p.tag_ar, p.title_en, p.title_ar, p.title)
      INTO
        v_discount_type,
        v_discount_value,
        v_discount_label
      FROM public.promotions p
      WHERE p.is_active IS TRUE
        AND p.lounge_id = v_lounge_id
        AND COALESCE(p.is_room_specific, false) IS FALSE
        AND p.room_id IS NULL
        AND COALESCE(p.discount_value, 0) > 0
        AND (p.expires_at IS NULL OR p.expires_at > now())
      ORDER BY p.created_at DESC, p.id DESC
      LIMIT 1;

      IF FOUND THEN
        v_discount_source := 'lounge';
      ELSE
        SELECT
          'percentage',
          l.discount_percentage::numeric,
          COALESCE(l.discount_title_en, l.discount_title_ar)
        INTO
          v_discount_type,
          v_discount_value,
          v_discount_label
        FROM public.lounges l
        WHERE l.id = v_lounge_id
          AND COALESCE(l.has_discount, false) IS TRUE
          AND COALESCE(l.discount_percentage, 0) > 0
          AND (
            l.discount_expires_at IS NULL
            OR l.discount_expires_at > now()
          );

        IF FOUND THEN
          v_discount_source := 'lounge';
        END IF;
      END IF;
    END IF;

    v_original_subtotal :=
      round(v_priced_room_subtotal + (v_controller_rate * v_duration_hours),2);

    IF COALESCE(v_discount_value, 0) > 0 THEN
      IF lower(COALESCE(v_discount_type, 'percentage')) = 'fixed' THEN
        v_promo_discount :=
          LEAST(v_priced_room_subtotal, GREATEST(0, v_discount_value));
      ELSE
        v_promo_discount :=
          ROUND(
            v_priced_room_subtotal
            * LEAST(GREATEST(v_discount_value, 0), 100)
            / 100.0,
            2
          );
      END IF;
    ELSE
      v_promo_discount := 0;
    END IF;

    v_discounted_subtotal :=
      round(GREATEST(0, v_original_subtotal - v_promo_discount),2);

    v_discounted_base_rate := CASE
      WHEN v_duration_hours > 0
      THEN GREATEST(
        0,
        (v_priced_room_subtotal - v_promo_discount) / v_duration_hours
      )
      ELSE v_effective_rate
    END;

    IF jsonb_array_length(v_rooms) = 0 THEN
      v_primary_rate := v_discounted_base_rate;
      v_primary_discounted_subtotal := v_discounted_subtotal;
    END IF;

    v_original_rooms_total :=
      v_original_rooms_total + v_original_subtotal;

    v_discounted_rooms_total :=
      v_discounted_rooms_total + v_discounted_subtotal;

    v_room_discount_total :=
      v_room_discount_total + v_promo_discount;

    v_rooms := v_rooms || jsonb_build_array(
      jsonb_build_object(
        'room_id', v_room_id,
        'room_name_ar', v_room.name_ar,
        'room_name_en', v_room.name_en,
        'play_mode', v_play_mode,
        'extra_controllers', v_extra_controllers,
        'base_hourly_rate', v_base_rate,
        'effective_hourly_rate', v_effective_rate,
        'pricing_segments', COALESCE(v_pricing->'segments', '[]'::jsonb),
        'controller_hourly_rate', v_controller_rate,
        'applied_hourly_rate', v_discounted_base_rate + v_controller_rate,
        'original_subtotal', v_original_subtotal,
        'discounted_subtotal', v_discounted_subtotal,
        'promo_discount_amount', v_promo_discount,
        'discount_type', v_discount_type,
        'discount_value', v_discount_value,
        'discount_label', v_discount_label,
        'discount_source', v_discount_source
      )
    );
  END LOOP;

  IF p_extra_items IS NULL THEN
    p_extra_items := '[]'::jsonb;
  END IF;

  IF jsonb_typeof(p_extra_items) <> 'array'
     OR jsonb_array_length(p_extra_items) > 50 THEN
    RAISE EXCEPTION 'Extra items must be a JSON array'
      USING ERRCODE = '22023';
  END IF;

  FOR v_extra IN
    SELECT e.value
    FROM jsonb_array_elements(p_extra_items) e(value)
  LOOP
    BEGIN
      v_extra_id := NULLIF(
        COALESCE(
          v_extra->>'extra_id',
          v_extra->>'id',
          v_extra->>'product_id'
        ),
        ''
      )::uuid;
      v_quantity := COALESCE((v_extra->>'quantity')::integer, 1);
    EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
      RAISE EXCEPTION 'Invalid extra item' USING ERRCODE = '22023';
    END;

    IF v_extra_id IS NULL OR v_quantity < 1 OR v_quantity > 100 THEN
      RAISE EXCEPTION 'Invalid extra item quantity'
        USING ERRCODE = '22023';
    END IF;

    SELECT
      e.id,
      e.name,
      e.name_ar,
      e.name_en,
      e.price,
      e.track_stock,
      e.stock_quantity
    INTO v_extra_row
    FROM public.extras e
    WHERE e.id = v_extra_id
      AND e.lounge_id = v_lounge_id
      AND e.is_active IS TRUE
      AND e.is_available IS TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Extra unavailable: %', v_extra_id
        USING ERRCODE = '23514';
    END IF;

    IF v_extra_row.track_stock IS TRUE
       AND COALESCE(v_extra_row.stock_quantity, 0) < v_quantity THEN
      RAISE EXCEPTION 'Extra has insufficient stock: %', v_extra_id
        USING ERRCODE = '23514';
    END IF;

    v_extras_total :=
      v_extras_total + round(v_extra_row.price * v_quantity,2);

    v_extras := v_extras || jsonb_build_array(
      jsonb_build_object(
        'extra_id', v_extra_id,
        'name', COALESCE(
          v_extra_row.name_ar,
          v_extra_row.name_en,
          v_extra_row.name
        ),
        'quantity', v_quantity,
        'unit_price', v_extra_row.price,
        'total_price', round(v_extra_row.price * v_quantity,2)
      )
    );
  END LOOP;

  IF v_voucher_code IS NOT NULL THEN
    SELECT uv.*
    INTO v_voucher
    FROM public.user_vouchers uv
    WHERE upper(btrim(uv.code)) = v_voucher_code
      AND uv.user_id = p_user_id
      AND uv.status = 'active'
      AND (uv.expires_at IS NULL OR uv.expires_at > now())
    LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'VOUCHER_INVALID' USING ERRCODE = '23514';
    END IF;

    IF v_voucher.reward_type = 'discount_fixed' THEN
      v_voucher_discount := GREATEST(
        0,
        COALESCE(v_voucher.reward_value, 0)
      );
    ELSIF v_voucher.reward_type = 'free_hour' THEN
      v_voucher_discount := GREATEST(
        0,
        LEAST(
          v_primary_discounted_subtotal,
          v_primary_rate * COALESCE(v_voucher.reward_value, 0)
        )
      );
    ELSE
      RAISE EXCEPTION 'Unsupported voucher type'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  v_voucher_discount := round(LEAST(
    v_voucher_discount,
    v_discounted_rooms_total + v_extras_total
  ),2);

  RETURN jsonb_build_object(
    'success', true,
    'hold_token', p_hold_token,
    'lounge_id', v_lounge_id,
    'start_at', v_start_at,
    'end_at', v_end_at,
    'duration_minutes',
      round(extract(epoch FROM (v_end_at - v_start_at)) / 60.0)::integer,
    'rooms', v_rooms,
    'extras', v_extras,
    'original_rooms_total', v_original_rooms_total,
    'promo_discount_total', v_room_discount_total,
    'discounted_rooms_total', v_discounted_rooms_total,
    'extras_total', v_extras_total,
    'voucher_code', v_voucher_code,
    'voucher_discount', v_voucher_discount,
    'original_total', v_original_rooms_total + v_extras_total,
    'final_total',
      GREATEST(
        0,
        v_discounted_rooms_total + v_extras_total - v_voucher_discount
      )
  );
END;
$function$
;

REVOKE ALL ON FUNCTION private.build_my_booking_checkout_quote(uuid,uuid,jsonb,jsonb,text) FROM PUBLIC;
NOTIFY pgrst, 'reload schema';
COMMIT;
