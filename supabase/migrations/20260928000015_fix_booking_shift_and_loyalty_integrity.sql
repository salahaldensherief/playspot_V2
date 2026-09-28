BEGIN;

-- Accepted bookings are guarded by an open-shift trigger. Once a booking is
-- started, attach the operational session to that exact shift for accounting.
CREATE OR REPLACE FUNCTION public.attach_booking_to_active_shift()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_shift_id uuid;
  v_shift_lounge_id uuid;
  v_shift_status text;
  v_requires_open_shift boolean :=
    NEW.status::text = 'in_progress' OR NEW.actual_start_time IS NOT NULL;
BEGIN
  IF v_requires_open_shift
     AND NEW.shift_id IS NULL
     AND NEW.lounge_id IS NOT NULL THEN
    SELECT id
    INTO v_shift_id
    FROM public.shifts
    WHERE lounge_id = NEW.lounge_id
      AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF v_shift_id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'NO_OPEN_SHIFT';
    END IF;

    NEW.shift_id := v_shift_id;
  END IF;

  IF NEW.shift_id IS NOT NULL THEN
    SELECT lounge_id, status
    INTO v_shift_lounge_id, v_shift_status
    FROM public.shifts
    WHERE id = NEW.shift_id;

    IF v_shift_lounge_id IS NULL THEN
      RAISE EXCEPTION 'The selected shift does not exist.';
    END IF;

    IF NEW.lounge_id IS DISTINCT FROM v_shift_lounge_id THEN
      RAISE EXCEPTION 'Booking and shift must belong to the same lounge.';
    END IF;

    IF v_requires_open_shift AND v_shift_status <> 'open' THEN
      RAISE EXCEPTION 'An active booking must be linked to an open shift.';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- Keep one review loyalty trigger. award_points is idempotent, but invoking
-- the function twice still repeats unnecessary mission and notification work.
DROP TRIGGER IF EXISTS trg_review_loyalty ON public.lounge_reviews;

-- Backfill only completed bookings that have no booking-linked transaction in
-- either the legacy or canonical loyalty contracts.
DO $function$
DECLARE
  v_booking record;
BEGIN
  FOR v_booking IN
    SELECT b.id
    FROM public.bookings AS b
    WHERE b.status = 'completed'::public.booking_status
      AND b.user_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.points_transactions AS pt
        WHERE pt.user_id = b.user_id
          AND (
            pt.reference_id = b.id
            OR pt.source_id = b.id
            OR pt.metadata->>'booking_id' = b.id::text
          )
      )
    ORDER BY b.created_at, b.id
  LOOP
    PERFORM public.award_points_for_booking(v_booking.id);
  END LOOP;
END;
$function$;

COMMIT;
