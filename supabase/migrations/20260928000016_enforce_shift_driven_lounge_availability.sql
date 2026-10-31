BEGIN;

-- Lounge availability is operational state derived from shifts. It must not
-- be possible to advertise a lounge as open without someone operating it.
CREATE OR REPLACE FUNCTION private.enforce_shift_driven_lounge_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  NEW.is_open := EXISTS (
    SELECT 1
    FROM public.shifts AS s
    WHERE s.lounge_id = NEW.id
      AND s.status = 'open'
      AND s.closed_at IS NULL
  );

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION private.enforce_shift_driven_lounge_status()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_enforce_shift_driven_lounge_status
ON public.lounges;

CREATE TRIGGER trg_enforce_shift_driven_lounge_status
BEFORE INSERT OR UPDATE OF is_open ON public.lounges
FOR EACH ROW
EXECUTE FUNCTION private.enforce_shift_driven_lounge_status();

CREATE OR REPLACE FUNCTION public.sync_lounge_open_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_old_lounge_id uuid;
  v_new_lounge_id uuid;
BEGIN
  v_old_lounge_id := CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.lounge_id END;
  v_new_lounge_id := CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE NEW.lounge_id END;

  UPDATE public.lounges AS l
  SET is_open = EXISTS (
    SELECT 1
    FROM public.shifts AS s
    WHERE s.lounge_id = l.id
      AND s.status = 'open'
      AND s.closed_at IS NULL
  )
  WHERE l.id IN (v_new_lounge_id, v_old_lounge_id)
    AND l.is_open IS DISTINCT FROM EXISTS (
      SELECT 1
      FROM public.shifts AS s
      WHERE s.lounge_id = l.id
        AND s.status = 'open'
        AND s.closed_at IS NULL
    );

  RETURN COALESCE(NEW, OLD);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.sync_lounge_open_status()
FROM PUBLIC, anon, authenticated;

-- Booking creation is an operational action. A hold may have been acquired
-- just before a shift closed, so the insert remains the final authority.
CREATE OR REPLACE FUNCTION public.check_active_shift_before_booking()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.status IN (
       'pending'::public.booking_status,
       'upcoming'::public.booking_status,
       'in_progress'::public.booking_status
     )
     AND NOT EXISTS (
       SELECT 1
       FROM public.shifts AS s
       WHERE s.lounge_id = NEW.lounge_id
         AND s.status = 'open'
         AND s.closed_at IS NULL
     ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'NO_OPEN_SHIFT';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.check_active_shift_before_booking()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS tr_check_active_shift ON public.bookings;

CREATE TRIGGER tr_check_active_shift
BEFORE INSERT ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.check_active_shift_before_booking();

-- Reconcile any state written before the invariant was enforced.
UPDATE public.lounges AS l
SET is_open = EXISTS (
  SELECT 1
  FROM public.shifts AS s
  WHERE s.lounge_id = l.id
    AND s.status = 'open'
    AND s.closed_at IS NULL
)
WHERE l.is_open IS DISTINCT FROM EXISTS (
  SELECT 1
  FROM public.shifts AS s
  WHERE s.lounge_id = l.id
    AND s.status = 'open'
    AND s.closed_at IS NULL
);

COMMIT;
