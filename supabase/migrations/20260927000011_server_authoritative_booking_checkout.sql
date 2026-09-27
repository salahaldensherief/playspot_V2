BEGIN;

CREATE OR REPLACE FUNCTION private.build_my_booking_checkout_quote(
  p_user_id uuid,
  p_hold_token uuid,
  p_room_requests jsonb,
  p_extra_items jsonb DEFAULT '[]'::jsonb,
  p_voucher_code text DEFAULT NULL::text
)
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

  SELECT count(*),
         min(h.lounge_id),
         min(h.start_at),
         min(h.end_at)
  INTO v_hold_count, v_lounge_id, v_start_at, v_end_at
  FROM public.booking_holds h
  WHERE h.hold_token = p_hold_token
    AND h.user_id = p_user_id
    AND h.released_at IS NULL
    AND h.expires_at > now();

  IF v_hold_count < 1 THEN
    RAISE EXCEPTION 'BOOKING_HOLD_EXPIRED' USING ERRCODE = '55000';
  END IF;

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
      AND r.is_available IS TRUE;

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

    v_controller_rate :=
      v_extra_controllers * COALESCE(v_room.extra_controller_price, 0);

    v_discounted_base_rate := v_base_rate;
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

    IF COALESCE(v_discount_value, 0) > 0 THEN
      IF lower(COALESCE(v_discount_type, 'percentage')) = 'fixed' THEN
        v_discounted_base_rate :=
          GREATEST(0, v_base_rate - v_discount_value);
      ELSE
        v_discounted_base_rate :=
          GREATEST(
            0,
            v_base_rate * (
              1 - LEAST(GREATEST(v_discount_value, 0), 100) / 100.0
            )
          );
      END IF;
    END IF;

    v_original_subtotal :=
      (v_base_rate + v_controller_rate) * v_duration_hours;

    v_discounted_subtotal :=
      (v_discounted_base_rate + v_controller_rate) * v_duration_hours;

    v_promo_discount :=
      GREATEST(0, v_original_subtotal - v_discounted_subtotal);

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
      v_extras_total + (v_extra_row.price * v_quantity);

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
        'total_price', v_extra_row.price * v_quantity
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

  v_voucher_discount := LEAST(
    v_voucher_discount,
    v_discounted_rooms_total + v_extras_total
  );

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
$function$;

REVOKE ALL ON FUNCTION private.build_my_booking_checkout_quote(
  uuid, uuid, jsonb, jsonb, text
) FROM PUBLIC, anon, authenticated;


CREATE OR REPLACE FUNCTION public.quote_my_booking_checkout(
  p_hold_token uuid,
  p_room_requests jsonb,
  p_extra_items jsonb DEFAULT '[]'::jsonb,
  p_voucher_code text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  RETURN private.build_my_booking_checkout_quote(
    v_user_id,
    p_hold_token,
    p_room_requests,
    p_extra_items,
    p_voucher_code
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.quote_my_booking_checkout(
  uuid, jsonb, jsonb, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.quote_my_booking_checkout(
  uuid, jsonb, jsonb, text
) TO authenticated, service_role;


CREATE OR REPLACE FUNCTION public.create_my_booking_checkout(
  p_hold_token uuid,
  p_room_requests jsonb,
  p_extra_items jsonb DEFAULT '[]'::jsonb,
  p_voucher_code text DEFAULT NULL::text,
  p_payment_method text DEFAULT 'cash',
  p_sender_wallet_phone text DEFAULT NULL::text,
  p_receipt_url text DEFAULT NULL::text
)
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
      v_promo_discount + CASE WHEN v_primary THEN v_voucher_discount ELSE 0 END;

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
      v_duration_minutes / 60.0,
      v_duration_minutes,
      v_play_mode,
      v_extra_controllers,
      'unpaid',
      v_clean_payment_method,
      v_discount_amount,
      v_discount_percentage,
      CASE
        WHEN v_primary AND NULLIF(btrim(p_voucher_code), '') IS NOT NULL
        THEN concat_ws(' + ', v_discount_label, 'voucher')
        ELSE v_discount_label
      END,
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
$function$;

REVOKE EXECUTE ON FUNCTION public.create_my_booking_checkout(
  uuid, jsonb, jsonb, text, text, text, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_my_booking_checkout(
  uuid, jsonb, jsonb, text, text, text, text
) TO authenticated, service_role;


CREATE OR REPLACE FUNCTION public.fn_validate_and_clamp_booking_price()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actual_hourly_rate numeric := 0;
  v_extra_controller_rate numeric := 0;
  v_addons numeric := 0;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
BEGIN
  IF COALESCE(NEW.duration_minutes, 0) <= 0
     OR NEW.duration_minutes > 1440 THEN
    RAISE EXCEPTION
      'Invalid booking duration: % minutes. Duration must be between 1 and 1440 minutes.',
      NEW.duration_minutes;
  END IF;

  IF NEW.room_id IS NULL THEN
    RAISE EXCEPTION
      'Cannot validate booking price: room_id is required.';
  END IF;

  SELECT
    COALESCE(
      CASE
        WHEN NEW.play_mode = 'multi'
             AND COALESCE(r.hourly_rate_multi, 0) > 0
        THEN r.hourly_rate_multi
        ELSE r.hourly_rate_single
      END,
      0
    ),
    GREATEST(0, COALESCE(NEW.extra_controllers, 0))
      * COALESCE(r.extra_controller_price, 0)
  INTO
    v_actual_hourly_rate,
    v_extra_controller_rate
  FROM public.rooms r
  WHERE r.id = NEW.room_id;

  IF v_actual_hourly_rate <= 0 THEN
    RAISE EXCEPTION
      'Cannot validate booking price: room % has no valid rate configured.',
      NEW.room_id;
  END IF;

  NEW.room_price :=
    (NEW.duration_minutes / 60.0)
    * (v_actual_hourly_rate + v_extra_controller_rate);

  v_addons := GREATEST(
    0,
    COALESCE(NEW.addons_price, NEW.addons_total, 0)
  );

  NEW.addons_price := v_addons;
  NEW.addons_total := v_addons;

  v_subtotal := NEW.room_price + v_addons;

  IF COALESCE(NEW.discount_amount, 0) > 0 THEN
    v_discount := LEAST(v_subtotal, NEW.discount_amount);
  ELSIF COALESCE(NEW.discount_percentage, 0) > 0 THEN
    v_discount := LEAST(
      v_subtotal,
      v_subtotal * (NEW.discount_percentage / 100.0)
    );
  ELSE
    v_discount := 0;
  END IF;

  NEW.discount_amount := v_discount;
  NEW.total_price := GREATEST(0, v_subtotal - v_discount);

  RETURN NEW;
END;
$function$;


DROP POLICY IF EXISTS "bookings_write_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_customer_or_branch" ON public.bookings;

DROP POLICY IF EXISTS "bookings_insert_branch_only" ON public.bookings;
CREATE POLICY "bookings_insert_branch_only"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (
  public._playspot_has_lounge_access(lounge_id)
);


COMMIT;
