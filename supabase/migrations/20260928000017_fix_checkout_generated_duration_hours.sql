BEGIN;

-- duration_hours is a generated column on public.bookings, so checkout must
-- write duration_minutes/start_time/end_time and let Postgres derive hours.
CREATE OR REPLACE FUNCTION public.create_my_booking_checkout(
  p_hold_token uuid,
  p_room_requests jsonb,
  p_extra_items jsonb DEFAULT '[]'::jsonb,
  p_voucher_code text DEFAULT NULL::text,
  p_payment_method text DEFAULT 'cash'::text,
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

COMMIT;
