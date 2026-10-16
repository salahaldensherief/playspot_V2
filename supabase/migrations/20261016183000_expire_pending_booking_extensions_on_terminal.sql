-- Finalised bookings cannot retain actionable, pending extension requests.
-- A pending request expires (it is NOT represented as a staff rejection).
-- Existing rows are intentionally not rewritten; review historical exceptions
-- separately to preserve their audit and financial context.
BEGIN;

CREATE OR REPLACE FUNCTION private.expire_pending_booking_extension_on_terminal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status IN (
    'completed'::public.booking_status,
    'cancelled'::public.booking_status,
    'rejected'::public.booking_status,
    'expired'::public.booking_status
  ) AND NEW.extension_status = 'pending' THEN
    NEW.extension_status := 'expired';
    -- Preserve requested_extension_minutes as evidence of the original request.
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.expire_pending_booking_extension_on_terminal()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

DROP TRIGGER IF EXISTS expire_pending_booking_extension_on_terminal ON public.bookings;
CREATE TRIGGER expire_pending_booking_extension_on_terminal
BEFORE UPDATE OF status, extension_status ON public.bookings
FOR EACH ROW
WHEN (NEW.extension_status = 'pending')
EXECUTE FUNCTION private.expire_pending_booking_extension_on_terminal();

COMMIT;
