BEGIN;

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
      v_priced_room_subtotal + (v_controller_rate * v_duration_hours);

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
      GREATEST(0, v_original_subtotal - v_promo_discount);

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

COMMIT;
