-- REVIEW ONLY: no hosted deployment. PostgreSQL 15+ required.
-- Preserve the legacy projection while enforcing the caller's base-table RLS.
BEGIN;
ALTER VIEW public.slot_waitlist SET (security_invoker = true);
CREATE OR REPLACE FUNCTION public.fn_slot_waitlist_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_time time without time zone := COALESCE(NEW.slot_time, '18:00:00'::time);
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF NEW.user_id IS NOT NULL AND NEW.user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'Cannot create another customer request' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles AS actor
    WHERE actor.id = v_actor AND actor.is_active IS TRUE AND actor.is_banned IS FALSE) THEN
    RAISE EXCEPTION 'Active account required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rooms AS resource
    WHERE resource.id = NEW.room_id AND resource.lounge_id = NEW.lounge_id) THEN
    RAISE EXCEPTION 'Room does not belong to the lounge' USING ERRCODE = '42501';
  END IF;
  IF COALESCE(NEW.status, 'waiting') NOT IN ('waiting', 'active') THEN
    RAISE EXCEPTION 'Cannot create a claimed or completed request' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.booking_waitlist (
    user_id, lounge_id, room_id, requested_date, duration_minutes,
    preferred_start_time, start_at, end_at, status
  ) VALUES (
    v_actor, NEW.lounge_id, NEW.room_id, NEW.date, 60,
    v_time, NEW.date + v_time, NEW.date + v_time + interval '60 minutes',
    COALESCE(NEW.status, 'waiting')
  ) RETURNING id INTO NEW.id;
  NEW.user_id := v_actor;
  NEW.slot_time := v_time;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON public.slot_waitlist FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.slot_waitlist TO authenticated;
COMMIT;
