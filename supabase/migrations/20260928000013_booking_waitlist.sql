BEGIN;

CREATE TABLE public.booking_waitlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  start_at timestamp without time zone NOT NULL,
  end_at timestamp without time zone NOT NULL,
  status text NOT NULL DEFAULT 'waiting'
    CHECK (status IN ('waiting', 'notified', 'cancelled', 'expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  notified_at timestamptz,
  CONSTRAINT booking_waitlist_valid_range CHECK (end_at > start_at)
);

CREATE UNIQUE INDEX booking_waitlist_one_active_request
ON public.booking_waitlist (user_id, room_id, start_at, end_at)
WHERE status = 'waiting';

CREATE INDEX booking_waitlist_dispatch_idx
ON public.booking_waitlist (start_at, created_at)
WHERE status = 'waiting';

ALTER TABLE public.booking_waitlist ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.booking_waitlist FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.booking_waitlist TO authenticated;
GRANT ALL ON public.booking_waitlist TO service_role;

CREATE POLICY booking_waitlist_read_own
ON public.booking_waitlist FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE FUNCTION public.join_booking_waitlist(
  p_room_id uuid,
  p_start_at timestamp without time zone,
  p_end_at timestamp without time zone
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_lounge_id uuid;
  v_opening time without time zone;
  v_closing time without time zone;
  v_operational_date date;
  v_operational_start timestamp without time zone;
  v_operational_end timestamp without time zone;
  v_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_room_id IS NULL OR p_start_at IS NULL OR p_end_at IS NULL
     OR p_end_at <= p_start_at
     OR p_end_at - p_start_at > interval '6 hours'
     OR p_end_at - p_start_at < interval '15 minutes'
     OR p_start_at < (now() AT TIME ZONE 'Africa/Cairo') + interval '10 minutes'
     OR p_start_at > (now() AT TIME ZONE 'Africa/Cairo') + interval '30 days' THEN
    RAISE EXCEPTION 'Invalid waitlist slot' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_room_id::text, 0)
  );

  SELECT r.lounge_id, l.opening_time, l.closing_time
  INTO v_lounge_id, v_opening, v_closing
  FROM public.rooms r
  JOIN public.lounges l ON l.id = r.lounge_id
  WHERE r.id = p_room_id
    AND r.is_active IS TRUE AND r.is_available IS TRUE
    AND COALESCE(r.status, '') <> 'deleted'
    AND l.is_active IS TRUE AND l.is_open IS TRUE;

  IF v_lounge_id IS NULL OR v_opening IS NULL OR v_closing IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'ROOM_UNAVAILABLE');
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('waitlist-user:' || v_user_id::text, 0)
  );

  v_operational_date := p_start_at::date;
  IF v_closing <= v_opening AND p_start_at::time < v_closing THEN
    v_operational_date := v_operational_date - 1;
  END IF;
  v_operational_start := v_operational_date + v_opening;
  v_operational_end := v_operational_date + v_closing;
  IF v_closing <= v_opening THEN
    v_operational_end := v_operational_end + interval '1 day';
  END IF;

  IF p_start_at < v_operational_start OR p_end_at > v_operational_end THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'OUTSIDE_WORKING_HOURS');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.room_id = p_room_id
      AND b.status IN ('pending'::public.booking_status,
                       'upcoming'::public.booking_status,
                       'in_progress'::public.booking_status)
      AND (b.status <> 'pending'::public.booking_status
           OR b.expires_at IS NULL OR b.expires_at > now())
      AND b.booking_period && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) AND NOT EXISTS (
    SELECT 1 FROM public.booking_holds h
    WHERE h.room_id = p_room_id AND h.released_at IS NULL
      AND h.expires_at > now()
      AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
          && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SLOT_AVAILABLE_NOW');
  END IF;

  SELECT w.id INTO v_id FROM public.booking_waitlist w
  WHERE w.user_id = v_user_id AND w.room_id = p_room_id
    AND w.start_at = p_start_at AND w.end_at = p_end_at
    AND w.status = 'waiting';
  IF v_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'waitlist_id', v_id);
  END IF;

  IF (SELECT count(*) FROM public.booking_waitlist w
      WHERE w.user_id = v_user_id AND w.status = 'waiting') >= 20 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'WAITLIST_LIMIT');
  END IF;

  INSERT INTO public.booking_waitlist (user_id, lounge_id, room_id, start_at, end_at)
  VALUES (v_user_id, v_lounge_id, p_room_id, p_start_at, p_end_at)
  ON CONFLICT (user_id, room_id, start_at, end_at)
    WHERE status = 'waiting' DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT w.id INTO v_id FROM public.booking_waitlist w
    WHERE w.user_id = v_user_id AND w.room_id = p_room_id
      AND w.start_at = p_start_at AND w.end_at = p_end_at
      AND w.status = 'waiting';
  END IF;

  RETURN jsonb_build_object('success', true, 'waitlist_id', v_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.join_booking_waitlist(uuid, timestamp, timestamp)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_booking_waitlist(uuid, timestamp, timestamp)
TO authenticated;

CREATE FUNCTION public.cancel_booking_waitlist(p_waitlist_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  UPDATE public.booking_waitlist
  SET status = 'cancelled'
  WHERE id = p_waitlist_id AND user_id = auth.uid() AND status = 'waiting';
  RETURN FOUND;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.cancel_booking_waitlist(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_booking_waitlist(uuid) TO authenticated;

CREATE FUNCTION public.process_booking_waitlist()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_entry public.booking_waitlist%ROWTYPE;
  v_sent integer := 0;
BEGIN
  UPDATE public.booking_waitlist
  SET status = 'expired'
  WHERE status = 'waiting'
    AND start_at <= (now() AT TIME ZONE 'Africa/Cairo') + interval '10 minutes';

  FOR v_entry IN
    SELECT w.* FROM public.booking_waitlist w
    WHERE w.status = 'waiting'
      AND w.start_at > (now() AT TIME ZONE 'Africa/Cairo') + interval '10 minutes'
      AND NOT EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.room_id = w.room_id
          AND b.status IN ('pending'::public.booking_status,
                           'upcoming'::public.booking_status,
                           'in_progress'::public.booking_status)
          AND (b.status <> 'pending'::public.booking_status
               OR b.expires_at IS NULL OR b.expires_at > now())
          AND b.booking_period && pg_catalog.tsrange(w.start_at, w.end_at, '[)')
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.booking_holds h
        WHERE h.room_id = w.room_id AND h.released_at IS NULL
          AND h.expires_at > now()
          AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
              && pg_catalog.tsrange(w.start_at, w.end_at, '[)')
      )
    ORDER BY w.created_at, w.id LIMIT 100 FOR UPDATE OF w SKIP LOCKED
  LOOP
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_entry.room_id::text, 0)
    );

    IF NOT EXISTS (
      SELECT 1 FROM public.rooms r JOIN public.lounges l ON l.id = r.lounge_id
      WHERE r.id = v_entry.room_id AND r.lounge_id = v_entry.lounge_id
        AND r.is_active IS TRUE AND r.is_available IS TRUE
        AND COALESCE(r.status, '') <> 'deleted'
        AND l.is_active IS TRUE AND l.is_open IS TRUE
    ) OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.room_id = v_entry.room_id
        AND b.status IN ('pending'::public.booking_status,
                         'upcoming'::public.booking_status,
                         'in_progress'::public.booking_status)
        AND (b.status <> 'pending'::public.booking_status
             OR b.expires_at IS NULL OR b.expires_at > now())
        AND b.booking_period && pg_catalog.tsrange(v_entry.start_at, v_entry.end_at, '[)')
    ) OR EXISTS (
      SELECT 1 FROM public.booking_holds h
      WHERE h.room_id = v_entry.room_id AND h.released_at IS NULL
        AND h.expires_at > now()
        AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
            && pg_catalog.tsrange(v_entry.start_at, v_entry.end_at, '[)')
    ) OR EXISTS (
      SELECT 1 FROM public.booking_waitlist w
      WHERE w.room_id = v_entry.room_id
        AND pg_catalog.tsrange(w.start_at, w.end_at, '[)')
            && pg_catalog.tsrange(v_entry.start_at, v_entry.end_at, '[)')
        AND w.status = 'notified' AND w.notified_at > now() - interval '10 minutes'
    ) THEN
      CONTINUE;
    END IF;

    UPDATE public.booking_waitlist
    SET status = 'notified', notified_at = now()
    WHERE id = v_entry.id AND status = 'waiting';

    INSERT INTO public.notifications (
      user_id, lounge_id, title_ar, title_en, body_ar, body_en,
      type, is_read, metadata, created_at
    ) VALUES (
      v_entry.user_id, v_entry.lounge_id,
      'الموعد الذي طلبته قد يكون متاحًا',
      'Your requested slot may be available',
      'تحقق من إتاحة الغرفة وأكمل الحجز سريعًا. التنبيه لا يحجز الغرفة لك.',
      'Check availability and book soon. This alert does not reserve the room.',
      'booking', false,
      jsonb_build_object('event', 'waitlist_available', 'waitlist_id', v_entry.id,
        'lounge_id', v_entry.lounge_id, 'room_id', v_entry.room_id,
        'start_at', v_entry.start_at, 'end_at', v_entry.end_at),
      now()
    );
    v_sent := v_sent + 1;
  END LOOP;

  RETURN v_sent;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.process_booking_waitlist() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_booking_waitlist() TO service_role;

CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule(
  'playspot-booking-waitlist', '* * * * *',
  'SELECT public.process_booking_waitlist()'
);

COMMIT;
