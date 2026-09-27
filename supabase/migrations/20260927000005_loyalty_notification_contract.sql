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
  WHERE b.id = p_booking_id;

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

CREATE OR REPLACE FUNCTION public.trg_award_points_on_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_valid boolean;
  v_award jsonb;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.bookings AS b
    WHERE b.id = NEW.booking_id
      AND b.user_id = NEW.user_id
      AND b.status = 'completed'::public.booking_status
  )
  INTO v_valid;

  IF NOT v_valid THEN
    RETURN NEW;
  END IF;

  v_award := public.award_points(
    p_user_id => NEW.user_id,
    p_points => 15,
    p_type => 'earn_review',
    p_reference_id => NEW.id,
    p_description => 'نقاط من تقييم صالة',
    p_source_type => 'lounge_review',
    p_source_id => NEW.id,
    p_idempotency_key => 'review:' || NEW.user_id::text || ':' || NEW.id::text,
    p_metadata => jsonb_build_object(
      'review_id', NEW.id,
      'booking_id', NEW.booking_id,
      'lounge_id', NEW.lounge_id
    )
  );

  IF COALESCE((v_award->>'applied')::boolean, false) IS TRUE THEN
    PERFORM public.advance_loyalty_mission(
      NEW.user_id,
      'write_review',
      1
    );
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_booking_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_lounge_name text;
  v_actor_type text;
  v_title_ar text;
  v_title_en text;
  v_body_ar text;
  v_body_en text;
BEGIN
  SELECT COALESCE(l.name_ar, l.name_en, l.name)
  INTO v_lounge_name
  FROM public.lounges AS l
  WHERE l.id = NEW.lounge_id;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.notifications (
      user_id,
      lounge_id,
      title_ar,
      title_en,
      body_ar,
      body_en,
      type,
      is_read,
      metadata,
      created_at
    )
    VALUES (
      NEW.user_id,
      NEW.lounge_id,
      'طلب الحجز وصل!',
      'Booking Request Received!',
      'طلبك في ' || COALESCE(v_lounge_name, 'الصالة') || ' وصل، مستني موافقة الإدارة',
      'Your request at ' || COALESCE(v_lounge_name, 'the lounge') || ' was received, waiting for approval',
      'booking',
      false,
      jsonb_build_object(
        'booking_id', NEW.id,
        'lounge_id', NEW.lounge_id,
        'status', NEW.status::text,
        'event', 'booking_created'
      ),
      now()
    );

  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'upcoming'::public.booking_status THEN
      INSERT INTO public.notifications (
        user_id,
        lounge_id,
        title_ar,
        title_en,
        body_ar,
        body_en,
        type,
        is_read,
        metadata,
        created_at
      )
      VALUES (
        NEW.user_id,
        NEW.lounge_id,
        'تم قبول حجزك! 🎉',
        'Booking Accepted! 🎉',
        'وافق صاحب الصالة على طلب حجزك في ' || COALESCE(v_lounge_name, ''),
        'Your booking at ' || COALESCE(v_lounge_name, '') || ' has been approved.',
        'booking',
        false,
        jsonb_build_object(
          'booking_id', NEW.id,
          'lounge_id', NEW.lounge_id,
          'status', NEW.status::text,
          'event', 'booking_approved'
        ),
        now()
      );

    ELSIF NEW.status IN (
      'cancelled'::public.booking_status,
      'rejected'::public.booking_status
    ) THEN
      v_actor_type := CASE
        WHEN auth.uid() = NEW.user_id THEN 'user'
        WHEN auth.uid() IS NULL THEN 'system'
        ELSE 'admin'
      END;

      IF NEW.status = 'cancelled'::public.booking_status
         AND v_actor_type = 'user' THEN
        v_title_ar := 'تم إلغاء حجزك بنجاح';
        v_title_en := 'Booking Cancelled Successfully';
        v_body_ar := 'تم إلغاء حجزك بنجاح. نأمل أن نراك مرة أخرى.';
        v_body_en := 'Your booking was cancelled successfully. We hope to see you again.';
      ELSIF v_actor_type = 'system' THEN
        v_title_ar := 'تم إلغاء الحجز تلقائيًا';
        v_title_en := 'Booking Cancelled Automatically';
        v_body_ar := 'تم إلغاء حجزك تلقائيًا بسبب انتهاء مهلة الحجز.';
        v_body_en := 'Your booking was cancelled automatically because the booking time limit expired.';
      ELSIF NEW.status = 'rejected'::public.booking_status THEN
        v_title_ar := 'لم تتم الموافقة على حجزك';
        v_title_en := 'Booking Not Approved';
        v_body_ar := 'نأسف، لم تتم الموافقة على حجزك من قبل إدارة الصالة.';
        v_body_en := 'Sorry, your booking was not approved by the lounge management.';
      ELSE
        v_title_ar := 'نأسف، تم إلغاء حجزك';
        v_title_en := 'Booking Cancelled by Management';
        v_body_ar := 'نأسف، تم إلغاء حجزك من قبل إدارة الصالة في ' || COALESCE(v_lounge_name, 'الصالة') || '.';
        v_body_en := 'Sorry, your booking at ' || COALESCE(v_lounge_name, 'the lounge') || ' was cancelled by the lounge management.';
      END IF;

      INSERT INTO public.notifications (
        user_id,
        lounge_id,
        title_ar,
        title_en,
        body_ar,
        body_en,
        type,
        is_read,
        metadata,
        created_at
      )
      VALUES (
        NEW.user_id,
        NEW.lounge_id,
        v_title_ar,
        v_title_en,
        v_body_ar,
        v_body_en,
        'booking',
        false,
        jsonb_build_object(
          'booking_id', NEW.id,
          'lounge_id', NEW.lounge_id,
          'status', NEW.status::text,
          'event', 'booking_status_changed',
          'cancellation_source', v_actor_type
        ),
        now()
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;


CREATE OR REPLACE FUNCTION public.check_and_send_booking_reminders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.notifications (
    id,
    user_id,
    title,
    body,
    title_ar,
    title_en,
    body_ar,
    body_en,
    type,
    is_read,
    created_at,
    metadata,
    lounge_id
  )
  SELECT
    gen_random_uuid(),
    b.user_id,
    r.title_ar,
    r.body_ar,
    r.title_ar,
    r.title_en,
    r.body_ar,
    r.body_en,
    'booking',
    false,
    now(),
    jsonb_build_object(
      'booking_id', b.id,
      'lounge_id', b.lounge_id,
      'event', 'booking_reminder:' || r.reminder_key,
      'reminder_key', r.reminder_key,
      'scheduled_for', CASE
        WHEN r.reminder_key = 'extension_offer'
          THEN upper(b.booking_period)
        ELSE b.date + b.start_time
      END,
      'extension_minutes', CASE
        WHEN r.reminder_key = 'extension_offer' THEN 60
        ELSE NULL
      END
    ),
    b.lounge_id
  FROM public.bookings AS b
  CROSS JOIN LATERAL (
    VALUES
      (
        'one_hour',
        'تذكير بموعد الحجز ⏰',
        'حجزك يبدأ خلال ساعة، حضّر نفسك واستمتع بوقتك!',
        'Booking reminder ⏰',
        'Your booking starts in one hour.'
      ),
      (
        'five_minutes',
        'حجزك سيبدأ بعد 5 دقائق ⏰',
        'حجزك في الصالة سيبدأ خلال 5 دقائق، استعد!',
        'Your booking starts in 5 minutes ⏰',
        'Your lounge booking starts in 5 minutes.'
      ),
      (
        'extension_offer',
        'هل تريد تمديد وقت الحجز؟ ⏰',
        'متبقي 5 دقائق على انتهاء حجزك. الساعة التالية متاحة، هل تريد تمديد الوقت؟',
        'Would you like to extend your booking? ⏰',
        'Your booking ends in 5 minutes. The next hour is available. Would you like to extend?'
      )
  ) AS r(reminder_key, title_ar, body_ar, title_en, body_en)
  WHERE b.user_id IS NOT NULL
    AND b.status IN ('upcoming', 'in_progress')
    AND (
      (
        r.reminder_key = 'one_hour'
        AND (b.date + b.start_time)
          BETWEEN (localtimestamp + interval '59 minutes')
          AND (localtimestamp + interval '61 minutes')
      )
      OR (
        r.reminder_key = 'five_minutes'
        AND (b.date + b.start_time)
          BETWEEN (localtimestamp + interval '4 minutes')
          AND (localtimestamp + interval '6 minutes')
      )
      OR (
        r.reminder_key = 'extension_offer'
        AND b.room_id IS NOT NULL
        AND upper(b.booking_period)
          BETWEEN (localtimestamp + interval '4 minutes')
          AND (localtimestamp + interval '6 minutes')
        AND NOT EXISTS (
          SELECT 1
          FROM public.bookings AS next_booking
          WHERE next_booking.id <> b.id
            AND next_booking.room_id = b.room_id
            AND next_booking.status IN ('upcoming', 'in_progress')
            AND next_booking.booking_period && tsrange(
              upper(b.booking_period),
              upper(b.booking_period) + interval '1 hour',
              '[)'
            )
        )
      )
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.notifications AS n
      WHERE n.user_id = b.user_id
        AND n.type = 'booking'
        AND n.metadata->>'booking_id' = b.id::text
        AND n.metadata->>'reminder_key' = r.reminder_key
        AND n.metadata->>'scheduled_for' = (
          CASE
            WHEN r.reminder_key = 'extension_offer'
              THEN upper(b.booking_period)
            ELSE b.date + b.start_time
          END
        )::text
    );
END;
$function$;

-- Prevent duplicate booking lifecycle notifications once the typed event
-- metadata contract is present. Historical rows without event metadata are
-- intentionally left untouched.
CREATE OR REPLACE FUNCTION public.guard_duplicate_booking_notification()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_booking_id text;
  v_event text;
  v_status text;
  v_source text;
  v_lock_key text;
BEGIN
  IF NEW.type IS DISTINCT FROM 'booking' OR NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_booking_id := NULLIF(NEW.metadata->>'booking_id', '');
  v_event := NULLIF(NEW.metadata->>'event', '');
  IF v_booking_id IS NULL OR v_event IS NULL THEN
    RETURN NEW;
  END IF;

  v_status := COALESCE(NEW.metadata->>'status', '');
  v_source := COALESCE(NEW.metadata->>'cancellation_source', '');
  v_lock_key :=
    NEW.user_id::text
    || ':booking:'
    || v_booking_id
    || ':'
    || v_event
    || ':'
    || v_status
    || ':'
    || v_source;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_lock_key, 0)
  );

  IF EXISTS (
    SELECT 1
    FROM public.notifications AS n
    WHERE n.user_id = NEW.user_id
      AND n.type = 'booking'
      AND n.metadata->>'booking_id' = v_booking_id
      AND COALESCE(n.metadata->>'event', '') = v_event
      AND COALESCE(n.metadata->>'status', '') = v_status
      AND COALESCE(n.metadata->>'cancellation_source', '') = v_source
  ) THEN
    RETURN NULL;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_duplicate_booking_notification
ON public.notifications;

CREATE TRIGGER trg_guard_duplicate_booking_notification
BEFORE INSERT ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.guard_duplicate_booking_notification();

COMMIT;
