BEGIN;

CREATE OR REPLACE FUNCTION public.get_booking_quote(
  p_hold_token uuid,
  p_room_requests jsonb,
  p_extras jsonb DEFAULT '[]'::jsonb,
  p_voucher_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_hold_count integer;
  v_hold_lounge_count integer;
  v_hold_start_count integer;
  v_hold_end_count integer;
  v_hold_lounge_id uuid;
  v_hold_start timestamp without time zone;
  v_hold_end timestamp without time zone;
  v_hold_expires_at timestamptz;
  v_hold_room_ids uuid[];
  v_requested_room_ids uuid[];
  v_request_count integer;
  v_distinct_request_count integer;
  v_duration_minutes integer;
  v_duration_hours numeric;
  v_request jsonb;
  v_room public.rooms%ROWTYPE;
  v_room_id uuid;
  v_play_mode text;
  v_extra_controllers integer;
  v_base_rate numeric;
  v_controller_rate numeric;
  v_discounted_base_rate numeric;
  v_original_subtotal numeric;
  v_discounted_subtotal numeric;
  v_promo_discount numeric;
  v_total_original_rooms numeric := 0;
  v_total_discounted_rooms numeric := 0;
  v_total_promo_discount numeric := 0;
  v_rooms_breakdown jsonb := '[]'::jsonb;
  v_promo_id uuid;
  v_promo_type text;
  v_promo_value numeric;
  v_promo_tag_ar text;
  v_promo_tag_en text;
  v_promo_source text;
  v_room_index integer := 0;
  v_primary_discounted_base_rate numeric := 0;
  v_primary_discounted_subtotal numeric := 0;
  v_extra_row record;
  v_extra public.extras%ROWTYPE;
  v_extras_breakdown jsonb := '[]'::jsonb;
  v_addons_total numeric := 0;
  v_voucher public.user_vouchers%ROWTYPE;
  v_voucher_discount numeric := 0;
  v_clean_voucher_code text := NULLIF(upper(btrim(p_voucher_code)), '');
  v_final_total numeric;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_hold_token IS NULL THEN
    RAISE EXCEPTION 'Booking hold token is required' USING ERRCODE = '22023';
  END IF;

  IF p_room_requests IS NULL
     OR jsonb_typeof(p_room_requests) <> 'array'
     OR jsonb_array_length(p_room_requests) < 1
     OR jsonb_array_length(p_room_requests) > 20 THEN
    RAISE EXCEPTION 'room_requests must contain 1 to 20 rooms'
      USING ERRCODE = '22023';
  END IF;

  IF p_extras IS NULL OR jsonb_typeof(p_extras) <> 'array' THEN
    RAISE EXCEPTION 'extras must be a JSON array' USING ERRCODE = '22023';
  END IF;

  SELECT
    count(*),
    count(DISTINCT h.lounge_id),
    count(DISTINCT h.start_at),
    count(DISTINCT h.end_at),
    min(h.lounge_id),
    min(h.start_at),
    min(h.end_at),
    min(h.expires_at),
    array_agg(h.room_id ORDER BY h.room_id)
  INTO
    v_hold_count,
    v_hold_lounge_count,
    v_hold_start_count,
    v_hold_end_count,
    v_hold_lounge_id,
    v_hold_start,
    v_hold_end,
    v_hold_expires_at,
    v_hold_room_ids
  FROM public.booking_holds AS h
  WHERE h.hold_token = p_hold_token
    AND h.user_id = v_user_id
    AND h.released_at IS NULL
    AND h.expires_at > now();

  IF v_hold_count = 0 THEN
    RAISE EXCEPTION 'BOOKING_HOLD_EXPIRED' USING ERRCODE = '55000';
  END IF;

  IF v_hold_lounge_count <> 1
     OR v_hold_start_count <> 1
     OR v_hold_end_count <> 1 THEN
    RAISE EXCEPTION 'Invalid booking hold' USING ERRCODE = '55000';
  END IF;

  SELECT
    count(*),
    count(DISTINCT room_id),
    array_agg(DISTINCT room_id ORDER BY room_id)
  INTO
    v_request_count,
    v_distinct_request_count,
    v_requested_room_ids
  FROM (
    SELECT (item->>'room_id')::uuid AS room_id
    FROM jsonb_array_elements(p_room_requests) AS q(item)
  ) AS requested;

  IF v_request_count <> v_distinct_request_count
     OR v_request_count <> v_hold_count
     OR v_requested_room_ids IS DISTINCT FROM v_hold_room_ids THEN
    RAISE EXCEPTION 'Room requests do not match the active hold'
      USING ERRCODE = '22023';
  END IF;

  v_duration_minutes :=
    floor(extract(epoch FROM (v_hold_end - v_hold_start)) / 60)::integer;

  IF v_duration_minutes <= 0 OR v_duration_minutes > 1440 THEN
    RAISE EXCEPTION 'Invalid held duration' USING ERRCODE = '22023';
  END IF;

  v_duration_hours := v_duration_minutes::numeric / 60.0;

  FOR v_request IN
    SELECT item
    FROM jsonb_array_elements(p_room_requests) WITH ORDINALITY AS q(item, ord)
    ORDER BY ord
  LOOP
    v_room_index := v_room_index + 1;
    v_room_id := (v_request->>'room_id')::uuid;
    v_play_mode := lower(COALESCE(NULLIF(v_request->>'play_mode', ''), 'single'));

    IF v_play_mode NOT IN ('single', 'multi') THEN
      RAISE EXCEPTION 'Invalid play mode for room %', v_room_id
        USING ERRCODE = '22023';
    END IF;

    BEGIN
      v_extra_controllers := COALESCE((v_request->>'extra_controllers')::integer, 0);
    EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
      RAISE EXCEPTION 'Invalid extra controller count' USING ERRCODE = '22023';
    END;

    IF v_extra_controllers < 0 OR v_extra_controllers > 4 THEN
      RAISE EXCEPTION 'Extra controller count must be between 0 and 4'
        USING ERRCODE = '22023';
    END IF;

    SELECT r.*
    INTO v_room
    FROM public.rooms AS r
    WHERE r.id = v_room_id
      AND r.lounge_id = v_hold_lounge_id
      AND r.is_active IS TRUE
      AND r.is_available IS TRUE
      AND COALESCE(r.status, '') <> 'deleted';

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Room is unavailable: %', v_room_id
        USING ERRCODE = '23514';
    END IF;

    v_base_rate := CASE
      WHEN v_play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0
        THEN v_room.hourly_rate_multi
      ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 0)
    END;

    IF v_base_rate <= 0 THEN
      RAISE EXCEPTION 'Room has no valid hourly rate: %', v_room_id
        USING ERRCODE = '23514';
    END IF;

    v_controller_rate :=
      v_extra_controllers * COALESCE(v_room.extra_controller_price, 0);

    v_promo_id := NULL;
    v_promo_type := NULL;
    v_promo_value := NULL;
    v_promo_tag_ar := NULL;
    v_promo_tag_en := NULL;
    v_promo_source := 'none';

    SELECT
      p.id,
      lower(p.discount_type),
      p.discount_value,
      p.tag_ar,
      p.tag_en
    INTO
      v_promo_id,
      v_promo_type,
      v_promo_value,
      v_promo_tag_ar,
      v_promo_tag_en
    FROM public.promotions AS p
    WHERE p.room_id = v_room_id
      AND p.is_active IS TRUE
      AND COALESCE(p.discount_value, 0) > 0
      AND (p.expires_at IS NULL OR p.expires_at > now())
    ORDER BY p.created_at DESC, p.id
    LIMIT 1;

    IF v_promo_id IS NOT NULL THEN
      v_promo_source := 'room';
    ELSE
      SELECT
        p.id,
        lower(p.discount_type),
        p.discount_value,
        p.tag_ar,
        p.tag_en
      INTO
        v_promo_id,
        v_promo_type,
        v_promo_value,
        v_promo_tag_ar,
        v_promo_tag_en
      FROM public.promotions AS p
      WHERE p.lounge_id = v_hold_lounge_id
        AND p.room_id IS NULL
        AND COALESCE(p.is_room_specific, false) IS FALSE
        AND p.is_active IS TRUE
        AND COALESCE(p.discount_value, 0) > 0
        AND (p.expires_at IS NULL OR p.expires_at > now())
      ORDER BY p.created_at DESC, p.id
      LIMIT 1;

      IF v_promo_id IS NOT NULL THEN
        v_promo_source := 'lounge';
      END IF;
    END IF;

    v_discounted_base_rate := v_base_rate;

    IF v_promo_id IS NOT NULL AND v_promo_type = 'percentage' THEN
      v_discounted_base_rate :=
        v_base_rate * (1 - LEAST(GREATEST(v_promo_value, 0), 100) / 100.0);
    ELSIF v_promo_id IS NOT NULL AND v_promo_type = 'fixed' THEN
      v_discounted_base_rate :=
        GREATEST(0, v_base_rate - GREATEST(v_promo_value, 0));
    END IF;

    v_original_subtotal :=
      round((v_base_rate + v_controller_rate) * v_duration_hours, 2);
    v_discounted_subtotal :=
      round((v_discounted_base_rate + v_controller_rate) * v_duration_hours, 2);
    v_promo_discount :=
      GREATEST(0, v_original_subtotal - v_discounted_subtotal);

    v_total_original_rooms := v_total_original_rooms + v_original_subtotal;
    v_total_discounted_rooms := v_total_discounted_rooms + v_discounted_subtotal;
    v_total_promo_discount := v_total_promo_discount + v_promo_discount;

    IF v_room_index = 1 THEN
      v_primary_discounted_base_rate := v_discounted_base_rate;
      v_primary_discounted_subtotal := v_discounted_subtotal;
    END IF;

    v_rooms_breakdown := v_rooms_breakdown || jsonb_build_array(
      jsonb_build_object(
        'room_id', v_room.id,
        'room_name', COALESCE(v_room.name_ar, v_room.name_en, v_room.name, ''),
        'play_mode', v_play_mode,
        'extra_controllers', v_extra_controllers,
        'extra_controller_price', COALESCE(v_room.extra_controller_price, 0),
        'original_hourly_rate', v_base_rate,
        'discounted_hourly_rate', round(v_discounted_base_rate, 2),
        'controller_hourly_rate', v_controller_rate,
        'original_subtotal', v_original_subtotal,
        'discounted_subtotal', v_discounted_subtotal,
        'promo_discount_amount', v_promo_discount,
        'promo_id', v_promo_id,
        'promo_source', v_promo_source,
        'promo_type', v_promo_type,
        'promo_value', COALESCE(v_promo_value, 0),
        'promo_tag_ar', v_promo_tag_ar,
        'promo_tag_en', v_promo_tag_en
      )
    );
  END LOOP;

  FOR v_extra_row IN
    SELECT
      (item->>'extra_id')::uuid AS extra_id,
      sum((item->>'quantity')::integer)::integer AS quantity
    FROM jsonb_array_elements(p_extras) AS q(item)
    GROUP BY (item->>'extra_id')::uuid
    ORDER BY (item->>'extra_id')::uuid
  LOOP
    IF v_extra_row.quantity < 1 OR v_extra_row.quantity > 100 THEN
      RAISE EXCEPTION 'Extra quantity must be between 1 and 100'
        USING ERRCODE = '22023';
    END IF;

    SELECT e.*
    INTO v_extra
    FROM public.extras AS e
    WHERE e.id = v_extra_row.extra_id
      AND e.lounge_id = v_hold_lounge_id
      AND e.is_active IS TRUE
      AND e.is_available IS TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Extra is unavailable: %', v_extra_row.extra_id
        USING ERRCODE = '23514';
    END IF;

    IF v_extra.track_stock IS TRUE
       AND COALESCE(v_extra.stock_quantity, 0) < v_extra_row.quantity THEN
      RAISE EXCEPTION 'Insufficient stock for extra: %', v_extra_row.extra_id
        USING ERRCODE = '23514';
    END IF;

    v_addons_total :=
      v_addons_total + (v_extra.price * v_extra_row.quantity);

    v_extras_breakdown := v_extras_breakdown || jsonb_build_array(
      jsonb_build_object(
        'extra_id', v_extra.id,
        'name', COALESCE(v_extra.name_ar, v_extra.name_en, v_extra.name),
        'name_ar', v_extra.name_ar,
        'name_en', v_extra.name_en,
        'quantity', v_extra_row.quantity,
        'unit_price', v_extra.price,
        'total_price', v_extra.price * v_extra_row.quantity
      )
    );
  END LOOP;

  IF v_clean_voucher_code IS NOT NULL THEN
    SELECT uv.*
    INTO v_voucher
    FROM public.user_vouchers AS uv
    WHERE upper(btrim(uv.code)) = v_clean_voucher_code
      AND uv.user_id = v_user_id
      AND uv.status = 'active'
      AND (uv.expires_at IS NULL OR uv.expires_at > now())
    ORDER BY uv.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'INVALID_VOUCHER' USING ERRCODE = '22023';
    END IF;

    IF v_voucher.reward_type = 'discount_fixed' THEN
      v_voucher_discount :=
        LEAST(v_primary_discounted_subtotal, GREATEST(v_voucher.reward_value, 0));
    ELSIF v_voucher.reward_type = 'free_hour' THEN
      v_voucher_discount := LEAST(
        v_primary_discounted_subtotal,
        v_primary_discounted_base_rate
          * LEAST(GREATEST(v_voucher.reward_value, 0), v_duration_hours)
      );
    ELSE
      RAISE EXCEPTION 'UNSUPPORTED_VOUCHER_TYPE' USING ERRCODE = '22023';
    END IF;
  END IF;

  v_voucher_discount := round(GREATEST(v_voucher_discount, 0), 2);
  v_final_total := round(
    GREATEST(
      0,
      v_total_discounted_rooms + v_addons_total - v_voucher_discount
    ),
    2
  );

  RETURN jsonb_build_object(
    'success', true,
    'hold_token', p_hold_token,
    'hold_expires_at', v_hold_expires_at,
    'lounge_id', v_hold_lounge_id,
    'start_at', v_hold_start,
    'end_at', v_hold_end,
    'duration_minutes', v_duration_minutes,
    'rooms', v_rooms_breakdown,
    'extras', v_extras_breakdown,
    'original_room_subtotal', round(v_total_original_rooms, 2),
    'discounted_room_subtotal', round(v_total_discounted_rooms, 2),
    'promotion_discount', round(v_total_promo_discount, 2),
    'addons_total', round(v_addons_total, 2),
    'voucher', CASE
      WHEN v_clean_voucher_code IS NULL THEN NULL
      ELSE jsonb_build_object(
        'id', v_voucher.id,
        'code', v_voucher.code,
        'reward_type', v_voucher.reward_type,
        'reward_value', v_voucher.reward_value,
        'discount_amount', v_voucher_discount
      )
    END,
    'voucher_discount', v_voucher_discount,
    'total_price', v_final_total
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_booking_quote(
  uuid, jsonb, jsonb, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_booking_quote(
  uuid, jsonb, jsonb, text
) TO authenticated, service_role;


CREATE OR REPLACE FUNCTION public.fn_validate_and_clamp_booking_price()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actual_hourly_rate numeric := 0;
  v_extra_controller_price numeric := 0;
  v_controller_hourly_rate numeric := 0;
  v_addons numeric := 0;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
BEGIN
  IF COALESCE(NEW.duration_minutes, 0) <= 0
     OR NEW.duration_minutes > 1440 THEN
    RAISE EXCEPTION 'Invalid booking duration'
      USING ERRCODE = '22023';
  END IF;

  IF NEW.room_id IS NULL THEN
    RAISE EXCEPTION 'room_id is required' USING ERRCODE = '22023';
  END IF;

  IF COALESCE(NEW.extra_controllers, 0) < 0
     OR COALESCE(NEW.extra_controllers, 0) > 4 THEN
    RAISE EXCEPTION 'Extra controller count must be between 0 and 4'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    CASE
      WHEN NEW.play_mode = 'multi' AND COALESCE(r.hourly_rate_multi, 0) > 0
        THEN r.hourly_rate_multi
      ELSE COALESCE(r.hourly_rate_single, r.hourly_rate, 0)
    END,
    COALESCE(r.extra_controller_price, 0)
  INTO
    v_actual_hourly_rate,
    v_extra_controller_price
  FROM public.rooms AS r
  WHERE r.id = NEW.room_id;

  IF v_actual_hourly_rate <= 0 THEN
    RAISE EXCEPTION 'Room has no valid rate configured'
      USING ERRCODE = '23514';
  END IF;

  v_controller_hourly_rate :=
    COALESCE(NEW.extra_controllers, 0) * v_extra_controller_price;

  NEW.duration_hours := NEW.duration_minutes::numeric / 60.0;
  NEW.room_price := round(
    (v_actual_hourly_rate + v_controller_hourly_rate)
      * NEW.duration_hours,
    2
  );

  v_addons := GREATEST(0, COALESCE(NEW.addons_price, NEW.addons_total, 0));
  NEW.addons_price := v_addons;
  NEW.addons_total := v_addons;

  v_subtotal := NEW.room_price + v_addons;

  IF COALESCE(NEW.discount_amount, 0) > 0 THEN
    v_discount := LEAST(v_subtotal, NEW.discount_amount);
  ELSIF COALESCE(NEW.discount_percentage, 0) > 0 THEN
    v_discount := LEAST(
      v_subtotal,
      v_subtotal * LEAST(GREATEST(NEW.discount_percentage, 0), 100) / 100.0
    );
  END IF;

  NEW.discount_amount := round(GREATEST(v_discount, 0), 2);
  NEW.total_price := round(
    GREATEST(0, v_subtotal - NEW.discount_amount),
    2
  );

  RETURN NEW;
END;
$function$;


CREATE OR REPLACE FUNCTION public.create_bookings_from_hold(
  p_hold_token uuid,
  p_room_requests jsonb,
  p_extras jsonb DEFAULT '[]'::jsonb,
  p_voucher_code text DEFAULT NULL,
  p_payment_method text DEFAULT 'manual_transfer',
  p_sender_wallet_phone text DEFAULT NULL,
  p_receipt_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_quote jsonb;
  v_hold record;
  v_profile record;
  v_lounge record;
  v_room_item jsonb;
  v_booking_id uuid;
  v_primary_booking_id uuid;
  v_booking_ids jsonb := '[]'::jsonb;
  v_index integer := 0;
  v_room_discount numeric;
  v_voucher_discount numeric;
  v_payment_method text := lower(COALESCE(NULLIF(btrim(p_payment_method), ''), 'manual_transfer'));
  v_sender_wallet text := NULLIF(btrim(p_sender_wallet_phone), '');
  v_receipt_url text := NULLIF(btrim(p_receipt_url), '');
  v_expires_at timestamptz;
  v_voucher_code text := NULLIF(upper(btrim(p_voucher_code)), '');
  v_consumed boolean;
  v_room_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF v_payment_method NOT IN ('cash', 'manual_transfer') THEN
    RAISE EXCEPTION 'Unsupported payment method' USING ERRCODE = '22023';
  END IF;

  SELECT
    min(h.lounge_id) AS lounge_id,
    min(h.start_at) AS start_at,
    min(h.end_at) AS end_at,
    min(h.expires_at) AS hold_expires_at,
    count(*) AS room_count
  INTO v_hold
  FROM public.booking_holds AS h
  WHERE h.hold_token = p_hold_token
    AND h.user_id = v_user_id
    AND h.released_at IS NULL
    AND h.expires_at > now()
  FOR UPDATE;

  IF v_hold.room_count IS NULL OR v_hold.room_count = 0 THEN
    RAISE EXCEPTION 'BOOKING_HOLD_EXPIRED' USING ERRCODE = '55000';
  END IF;

  FOR v_room_id IN
    SELECT h.room_id
    FROM public.booking_holds AS h
    WHERE h.hold_token = p_hold_token
      AND h.user_id = v_user_id
      AND h.released_at IS NULL
      AND h.expires_at > now()
    ORDER BY h.room_id
  LOOP
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_room_id::text, 0)
    );
  END LOOP;

  v_quote := public.get_booking_quote(
    p_hold_token,
    p_room_requests,
    p_extras,
    v_voucher_code
  );

  SELECT
    p.full_name,
    p.phone
  INTO v_profile
  FROM public.profiles AS p
  WHERE p.id = v_user_id;

  SELECT
    l.cash_grace_period_minutes
  INTO v_lounge
  FROM public.lounges AS l
  WHERE l.id = v_hold.lounge_id;

  v_expires_at := now() + make_interval(
    mins => GREATEST(
      COALESCE(v_lounge.cash_grace_period_minutes, 10),
      1
    )
  );

  v_voucher_discount :=
    COALESCE((v_quote->>'voucher_discount')::numeric, 0);

  FOR v_room_item IN
    SELECT item
    FROM jsonb_array_elements(v_quote->'rooms') WITH ORDINALITY AS q(item, ord)
    ORDER BY ord
  LOOP
    v_index := v_index + 1;

    v_room_discount :=
      COALESCE((v_room_item->>'promo_discount_amount')::numeric, 0);

    IF v_index = 1 THEN
      v_room_discount := v_room_discount + v_voucher_discount;
    END IF;

    INSERT INTO public.bookings (
      user_id,
      room_id,
      lounge_id,
      date,
      start_time,
      end_time,
      start_at,
      end_at,
      room_price,
      addons_price,
      addons_total,
      total_price,
      status,
      user_name,
      user_phone,
      room_name,
      duration_hours,
      duration_minutes,
      play_mode,
      extra_controllers,
      payment_status,
      payment_method,
      discount_amount,
      discount_percentage,
      discount_reason,
      receipt_url,
      sender_wallet_phone,
      expires_at
    )
    VALUES (
      v_user_id,
      (v_room_item->>'room_id')::uuid,
      v_hold.lounge_id,
      v_hold.start_at::date,
      v_hold.start_at::time,
      v_hold.end_at::time,
      v_hold.start_at::time,
      v_hold.end_at::time,
      COALESCE((v_room_item->>'original_subtotal')::numeric, 0),
      0,
      0,
      GREATEST(
        0,
        COALESCE((v_room_item->>'original_subtotal')::numeric, 0)
          - v_room_discount
      ),
      'pending'::public.booking_status,
      COALESCE(v_profile.full_name, ''),
      COALESCE(v_profile.phone, ''),
      COALESCE(v_room_item->>'room_name', ''),
      (v_quote->>'duration_minutes')::numeric / 60.0,
      (v_quote->>'duration_minutes')::integer,
      v_room_item->>'play_mode',
      COALESCE((v_room_item->>'extra_controllers')::integer, 0),
      'unpaid',
      v_payment_method,
      v_room_discount,
      0,
      CASE
        WHEN v_index = 1 AND v_voucher_code IS NOT NULL
          THEN 'server_promotion_and_voucher'
        WHEN COALESCE((v_room_item->>'promo_discount_amount')::numeric, 0) > 0
          THEN 'server_promotion'
        ELSE NULL
      END,
      CASE WHEN v_index = 1 THEN v_receipt_url ELSE NULL END,
      CASE WHEN v_payment_method = 'manual_transfer' THEN v_sender_wallet ELSE NULL END,
      v_expires_at
    )
    RETURNING id INTO v_booking_id;

    IF v_index = 1 THEN
      v_primary_booking_id := v_booking_id;
    END IF;

    v_booking_ids := v_booking_ids || jsonb_build_array(v_booking_id);
  END LOOP;

  IF v_primary_booking_id IS NULL THEN
    RAISE EXCEPTION 'No bookings were created' USING ERRCODE = '55000';
  END IF;

  IF jsonb_array_length(v_quote->'extras') > 0 THEN
    PERFORM public.place_canteen_order(
      v_primary_booking_id,
      v_quote->'extras',
      NULL
    );
  END IF;

  IF v_voucher_code IS NOT NULL THEN
    v_consumed := public.consume_voucher_by_code(
      v_voucher_code,
      v_primary_booking_id
    );

    IF NOT v_consumed THEN
      RAISE EXCEPTION 'VOUCHER_CONSUMPTION_FAILED' USING ERRCODE = '55000';
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
    'expires_at', v_expires_at,
    'quote', v_quote
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.create_bookings_from_hold(
  uuid, jsonb, jsonb, text, text, text, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_bookings_from_hold(
  uuid, jsonb, jsonb, text, text, text, text
) TO authenticated, service_role;


DROP POLICY IF EXISTS "bookings_write_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_customer_or_branch" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_branch_only" ON public.bookings;

CREATE POLICY "bookings_insert_branch_only"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (public._playspot_has_lounge_access(lounge_id));

COMMIT;
