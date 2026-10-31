BEGIN;

CREATE OR REPLACE FUNCTION public.award_points_for_booking(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid;
  v_amount numeric;
  v_points integer;
  v_award jsonb;
BEGIN
  SELECT b.user_id, b.total_price
  INTO v_user_id, v_amount
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
    AND b.status = 'completed'::public.booking_status
    AND COALESCE(b.payment_status, 'unpaid') = 'paid';

  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  v_points := GREATEST(
    1,
    ROUND(COALESCE(v_amount, 0) / 10.0)::integer
  );

  v_award := public.award_points(
    p_user_id => v_user_id,
    p_points => v_points,
    p_type => 'earn_booking',
    p_reference_id => p_booking_id,
    p_description => 'نقاط حجز رقم: ' || p_booking_id,
    p_source_type => 'booking',
    p_source_id => p_booking_id,
    p_idempotency_key => 'booking:' || p_booking_id::text,
    p_metadata => jsonb_build_object('booking_id', p_booking_id)
  );

  IF COALESCE((v_award->>'applied')::boolean, false) IS NOT TRUE THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications (
    user_id,
    title,
    title_ar,
    title_en,
    body,
    body_ar,
    body_en,
    type,
    metadata
  )
  VALUES (
    v_user_id,
    'Points Earned',
    'نقاط ولاء جديدة! 🎉',
    'New Loyalty Points Earned!',
    'تم إضافة ' || v_points || ' نقطة ولاء لحسابك مقابل حجزك',
    'تم إضافة ' || v_points || ' نقطة ولاء لحسابك مقابل حجزك',
    'You earned ' || v_points || ' loyalty points for your booking!',
    'loyalty_points',
    jsonb_build_object(
      'booking_id', p_booking_id,
      'points', v_points,
      'event', 'booking_completed'
    )
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.award_points_for_booking(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.award_points_for_booking(uuid)
TO service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.trg_award_points_on_booking_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_completed_count integer;
BEGIN
  -- Keep the trigger function safe if it is reused without the trigger predicate.
  IF NEW.status IS DISTINCT FROM 'completed'::public.booking_status
     OR COALESCE(NEW.payment_status, 'unpaid') <> 'paid' THEN
    RETURN NEW;
  END IF;

  PERFORM public.award_points_for_booking(NEW.id);

  IF NEW.user_id IS NOT NULL THEN
    SELECT COUNT(*)
    INTO v_completed_count
    FROM public.bookings AS b
    WHERE b.user_id = NEW.user_id
      AND b.status = 'completed'::public.booking_status
      AND COALESCE(b.payment_status, 'unpaid') = 'paid';

    IF v_completed_count = 1 THEN
      PERFORM public.advance_loyalty_mission(NEW.user_id, 'first_booking', 1);
    END IF;

    PERFORM public.advance_loyalty_mission(
      NEW.user_id,
      'two_completed_bookings',
      1
    );

    IF NEW.start_time >= TIME '10:00'
       AND NEW.start_time < TIME '16:00' THEN
      PERFORM public.advance_loyalty_mission(
        NEW.user_id,
        'off_peak_booking',
        1
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.trg_award_points_on_booking_complete()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_booking_completed_loyalty ON public.bookings;

CREATE TRIGGER trg_booking_completed_loyalty
AFTER UPDATE OF status, payment_status ON public.bookings
FOR EACH ROW
WHEN (
  NEW.status = 'completed'::public.booking_status
  AND NEW.payment_status = 'paid'
  AND (
    OLD.status IS DISTINCT FROM 'completed'::public.booking_status
    OR OLD.payment_status IS DISTINCT FROM 'paid'
  )
)
EXECUTE FUNCTION public.trg_award_points_on_booking_complete();

COMMIT;
