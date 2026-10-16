-- A session ending cannot retain an actionable extension request.
-- Preserve approved/rejected history. An unanswered pending request is expired,
-- not 'rejected' by an operator, and cannot be approved after session closure.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION private.expire_terminal_booking_extension()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.status IN (
      'completed'::public.booking_status,
      'cancelled'::public.booking_status
    ) AND NEW.extension_status = 'pending' THEN
    NEW.extension_status := 'expired';
    -- Retain requested_extension_minutes for historical audit;
    -- operational queries filter on extension_status='pending'.
  END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.expire_terminal_booking_extension()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

DROP TRIGGER IF EXISTS trg_expire_terminal_booking_extension
  ON public.bookings;
CREATE TRIGGER trg_expire_terminal_booking_extension
BEFORE UPDATE OF status, extension_status ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.expire_terminal_booking_extension();

-- One-time non-financial repair of any already-finished pending requests.
UPDATE public.bookings
SET extension_status = 'expired'
WHERE status IN (
    'completed'::public.booking_status,
    'cancelled'::public.booking_status
  )
  AND extension_status = 'pending';

COMMIT;
