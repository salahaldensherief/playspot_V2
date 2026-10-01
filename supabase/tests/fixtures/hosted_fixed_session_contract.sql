-- Read-only hosted function/trigger snapshot, 2026-10-01; disposable local fixtures only.
CREATE OR REPLACE FUNCTION public.quote_booking_price(p_room_id uuid, p_date date, p_start time without time zone, p_end time without time zone, p_play_mode text DEFAULT 'single'::text, p_extra_controllers integer DEFAULT 0, p_coupon_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_start_min integer;
  v_end_min integer;
  v_duration_min integer;
  v_base_rate numeric;
  v_controller_rate numeric := 0;
  v_controllers_amount numeric := 0;
  v_room_subtotal numeric := 0;
  v_promo_discount numeric := 0;
  v_final_total numeric := 0;
  v_play_mode text := lower(COALESCE(NULLIF(btrim(p_play_mode), ''), 'single'));
  v_currency text := 'EGP';
BEGIN
  IF p_room_id IS NULL OR p_date IS NULL OR p_start IS NULL OR p_end IS NULL THEN
    RAISE EXCEPTION 'Missing required arguments for price quote' USING ERRCODE = '22023';
  END IF;

  SELECT r.* INTO v_room FROM public.rooms r WHERE r.id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_room.lounge_id;

  v_start_min := (EXTRACT(HOUR FROM p_start) * 60 + EXTRACT(MINUTE FROM p_start))::integer;
  v_end_min := (EXTRACT(HOUR FROM p_end) * 60 + EXTRACT(MINUTE FROM p_end))::integer;

  -- Handle midnight crossing
  IF v_end_min <= v_start_min THEN
    v_end_min := v_end_min + 1440;
  END IF;

  v_duration_min := v_end_min - v_start_min;
  IF v_duration_min <= 0 OR v_duration_min > 1440 THEN
    RAISE EXCEPTION 'Invalid booking duration' USING ERRCODE = '22023';
  END IF;

  v_base_rate := CASE
    WHEN v_play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN v_room.hourly_rate_multi
    ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
  END;

  v_room_subtotal := ROUND((v_base_rate / 60.0) * v_duration_min, 2);

  -- Extra controllers
  IF COALESCE(p_extra_controllers, 0) > 0 THEN
    v_controller_rate := COALESCE(v_room.extra_controller_price, 0);
    v_controllers_amount := ROUND((p_extra_controllers * v_controller_rate * (v_duration_min / 60.0)), 2);
  END IF;

  -- Coupon check
  IF p_coupon_code IS NOT NULL AND btrim(p_coupon_code) <> '' THEN
    SELECT
      CASE
        WHEN p.discount_type = 'percentage' THEN ROUND((v_room_subtotal * (p.discount_value / 100.0)), 2)
        WHEN p.discount_type = 'fixed' THEN LEAST(v_room_subtotal, p.discount_value)
        ELSE 0
      END
    INTO v_promo_discount
    FROM public.promotions p
    WHERE p.is_active = true
      AND (p.room_id IS NULL OR p.room_id = p_room_id)
      AND lower(btrim(p.code)) = lower(btrim(p_coupon_code))
      AND (p.expires_at IS NULL OR p.expires_at > now())
    LIMIT 1;

    v_promo_discount := COALESCE(v_promo_discount, 0);
  END IF;

  v_final_total := GREATEST(0, (v_room_subtotal + v_controllers_amount) - v_promo_discount);

  RETURN jsonb_build_object(
    'room_id', p_room_id,
    'lounge_id', v_room.lounge_id,
    'date', p_date,
    'start_time', to_char(p_start, 'HH24:MI:SS'),
    'end_time', to_char(p_end, 'HH24:MI:SS'),
    'duration_minutes', v_duration_min,
    'play_mode', v_play_mode,
    'base_rate', v_base_rate,
    'room_subtotal', v_room_subtotal,
    'extra_controllers', COALESCE(p_extra_controllers, 0),
    'controllers_amount', v_controllers_amount,
    'addons_amount', 0,
    'discount_amount', v_promo_discount,
    'subtotal', v_room_subtotal + v_controllers_amount,
    'final_total', v_final_total,
    'currency', v_currency,
    'has_peak_rates', false,
    'segments', jsonb_build_array(
      jsonb_build_object(
        'from', to_char(p_start, 'HH24:MI:SS'),
        'to', to_char(p_end, 'HH24:MI:SS'),
        'minutes', v_duration_min,
        'rate', v_base_rate,
        'amount', v_room_subtotal
      )
    )
  );
END;
$function$;
CREATE OR REPLACE FUNCTION public.set_booking_first_booking()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_completed_count integer;
BEGIN
  SELECT COALESCE(completed_bookings_count, 0)
    INTO v_completed_count
  FROM public.profiles
  WHERE id = NEW.user_id
  FOR UPDATE;

  NEW.is_first_booking := (COALESCE(v_completed_count, 0) = 0);
  RETURN NEW;
END;
$function$;
CREATE OR REPLACE FUNCTION public.validate_booking_payment_policy()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_allow_cash boolean;
  v_require_first_prepaid boolean;
BEGIN
  SELECT allow_cash_payment, require_prepaid_first_time
    INTO v_allow_cash, v_require_first_prepaid
  FROM public.lounges
  WHERE id = NEW.lounge_id;

  IF NEW.payment_method = 'cash' AND COALESCE(v_allow_cash, false) = false THEN
    RAISE EXCEPTION 'Cash payment is disabled for this lounge';
  END IF;

  IF NEW.payment_method = 'cash'
     AND COALESCE(v_require_first_prepaid, true)
     AND NEW.is_first_booking THEN
    RAISE EXCEPTION 'First booking must use manual_transfer payment';
  END IF;

  IF NEW.payment_method = 'manual_transfer'
     AND NULLIF(btrim(NEW.sender_wallet_phone), '') IS NULL THEN
    RAISE EXCEPTION 'sender_wallet_phone is required for manual_transfer';
  END IF;

  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_bookings_set_first_booking BEFORE INSERT ON public.bookings FOR EACH ROW EXECUTE FUNCTION set_booking_first_booking();
CREATE TRIGGER trg_bookings_validate_payment_policy BEFORE INSERT OR UPDATE OF lounge_id, payment_method, sender_wallet_phone, is_first_booking ON public.bookings FOR EACH ROW EXECUTE FUNCTION validate_booking_payment_policy();
